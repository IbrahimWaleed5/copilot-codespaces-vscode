<?php

namespace App\Services\AiAgent;

use App\Services\GeminiSupportService;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Generates/edits images with a chain of providers (config/ai_media.php → image_providers):
 * Gemini first, then Cloudflare Workers AI, Hugging Face, and your own FLUX/SD/ComfyUI server.
 * A provider that is not configured is skipped; one that fails hands over to the next.
 */
class ImageGenerationManager
{
    private ?string $englishPrompt = null;

    public function __construct(
        private readonly GeminiImageGenerationService $gemini,
        private readonly GeminiSupportService $text,
        private readonly ComfyUiClient $comfy,
    ) {}

    /**
     * @param array{path:string,mime_type?:string,name?:string}|null $inputImage
     * @return array{path:string,absolute_path:string,name:string,mime:string,size:int,model:string,provider:string,usage:array|null}
     */
    public function generate(string $prompt, int $userId, int $ticketId, ?array $inputImage = null): array
    {
        $this->englishPrompt = null;
        $errors = [];

        foreach ($this->providers($inputImage !== null) as $provider) {
            try {
                $artifact = match ($provider) {
                    'gemini' => $this->gemini->generate($prompt, $userId, $ticketId, $inputImage) + ['provider' => 'gemini'],
                    'cloudflare' => $this->cloudflare($prompt, $userId, $ticketId),
                    'huggingface' => $this->huggingface($prompt, $userId, $ticketId),
                    'self_hosted' => $this->selfHosted($prompt, $userId, $ticketId, $inputImage),
                    default => null,
                };
                if (is_array($artifact)) {
                    return $artifact;
                }
            } catch (Throwable $e) {
                $errors[$provider] = $e->getMessage();
                Log::warning('Image provider failed; trying the next one.', ['provider' => $provider, 'error' => $e->getMessage()]);
            }
        }

        if ($errors === []) {
            throw new RuntimeException('لا يوجد مزود صور مضبوط على السيرفر. أضف مفتاح Gemini أو Cloudflare أو Hugging Face أو رابط خادمك.');
        }

        // The first provider's message is usually the most useful one (e.g. Gemini billing/quota).
        throw new RuntimeException(reset($errors));
    }

    /** Providers that are enabled, configured, and able to do this job (editing needs an image-to-image capable one). */
    public function providers(bool $editing = false): array
    {
        $order = (array) config('ai_media.image_providers', ['gemini']);

        return array_values(array_filter($order, function (string $provider) use ($editing): bool {
            return match ($provider) {
                'gemini' => trim((string) config('services.gemini.api_key')) !== '',
                'cloudflare' => ! $editing && filled(config('ai_media.cloudflare.account_id')) && filled(config('ai_media.cloudflare.api_token')),
                'huggingface' => ! $editing && filled(config('ai_media.huggingface.token')),
                'self_hosted' => filled(config('ai_media.self_hosted.url'))
                    && (config('ai_media.self_hosted.driver') === 'a1111'
                        || (! $editing && $this->comfy->configured('comfy_image_workflow'))),
                default => false,
            };
        }));
    }

    private function cloudflare(string $prompt, int $userId, int $ticketId): array
    {
        $model = (string) config('ai_media.cloudflare.image_model');
        $url = sprintf(
            'https://api.cloudflare.com/client/v4/accounts/%s/ai/run/%s',
            rawurlencode((string) config('ai_media.cloudflare.account_id')),
            $model // model ids contain "/" and "@", sent as-is like the official examples
        );

        $payload = ['prompt' => $this->english($prompt)];
        if (str_contains($model, 'flux')) {
            $payload['steps'] = max(1, min(8, (int) config('ai_media.cloudflare.steps', 8)));
        }

        $response = Http::withToken((string) config('ai_media.cloudflare.api_token'))
            ->timeout((int) config('ai_media.cloudflare.timeout', 90))
            ->post($url, $payload);

        $this->ensureOk($response, 'Cloudflare');

        // FLUX returns JSON {result:{image:base64}}; SDXL-style models return the PNG bytes directly.
        if (str_contains(strtolower((string) $response->header('Content-Type')), 'application/json')) {
            $b64 = (string) $response->json('result.image', '');
            $bytes = $b64 !== '' ? base64_decode($b64, true) : false;
            if (! $bytes) {
                throw new RuntimeException('Cloudflare لم يرجع صورة.');
            }

            return $this->store($bytes, 'image/jpeg', $userId, $ticketId, 'cloudflare', $model, false);
        }

        return $this->store($response->body(), $this->mimeOf($response), $userId, $ticketId, 'cloudflare', $model, false);
    }

    private function huggingface(string $prompt, int $userId, int $ticketId): array
    {
        $model = (string) config('ai_media.huggingface.image_model');
        $response = Http::withToken((string) config('ai_media.huggingface.token'))
            ->withHeaders(['Accept' => 'image/png'])
            ->timeout((int) config('ai_media.huggingface.timeout', 120))
            ->post(config('ai_media.huggingface.base_url') . '/' . $model, [
                'inputs' => $this->english($prompt),
            ]);

        $this->ensureOk($response, 'Hugging Face');
        if (! str_starts_with($this->mimeOf($response), 'image/')) {
            throw new RuntimeException('Hugging Face لم يرجع صورة.');
        }

        return $this->store($response->body(), $this->mimeOf($response), $userId, $ticketId, 'huggingface', $model, false);
    }

    /** @param array{path:string,mime_type?:string,name?:string}|null $inputImage */
    private function selfHosted(string $prompt, int $userId, int $ticketId, ?array $inputImage): array
    {
        $driver = (string) config('ai_media.self_hosted.driver', 'a1111');
        $negative = 'text, watermark, logo, blurry, distorted, low quality';

        if ($driver === 'comfyui') {
            $id = $this->comfy->queue('comfy_image_workflow', $this->english($prompt), $negative);
            $deadline = microtime(true) + (int) config('ai_media.self_hosted.timeout', 180);
            do {
                usleep(1_500_000);
                $result = $this->comfy->result($id, ['images']);
                if ($result['done'] ?? false) {
                    if (isset($result['error'])) {
                        throw new RuntimeException($result['error']);
                    }

                    return $this->store($result['bytes'], $result['mime'], $userId, $ticketId, 'comfyui', 'comfyui-workflow', false);
                }
            } while (microtime(true) < $deadline);

            throw new RuntimeException('انتهت مهلة خادم ComfyUI قبل أن يرجع الصورة.');
        }

        // AUTOMATIC1111 / Forge API (FLUX or Stable Diffusion checkpoints).
        $base = [
            'prompt' => $this->english($prompt),
            'negative_prompt' => $negative,
            'steps' => (int) config('ai_media.self_hosted.steps', 28),
            'width' => (int) config('ai_media.self_hosted.width', 1024),
            'height' => (int) config('ai_media.self_hosted.height', 768),
        ];
        $endpoint = '/sdapi/v1/txt2img';
        if ($inputImage && is_file((string) ($inputImage['path'] ?? ''))) {
            $endpoint = '/sdapi/v1/img2img';
            $base['init_images'] = [base64_encode((string) file_get_contents((string) $inputImage['path']))];
            $base['denoising_strength'] = 0.55;
        }

        $request = Http::acceptJson()->timeout((int) config('ai_media.self_hosted.timeout', 180));
        $token = trim((string) config('ai_media.self_hosted.token'));
        if ($token !== '') {
            $request = $request->withToken($token);
        }
        $response = $request->post(config('ai_media.self_hosted.url') . $endpoint, $base);
        $this->ensureOk($response, 'خادم الصور');

        $bytes = base64_decode((string) ($response->json('images.0') ?? ''), true);
        if (! $bytes) {
            throw new RuntimeException('خادم الصور لم يرجع صورة.');
        }

        return $this->store($bytes, 'image/png', $userId, $ticketId, 'self_hosted', 'a1111', $inputImage !== null);
    }

    /** FLUX/SD understand English far better than Arabic: let Gemini write the English image prompt once. */
    private function english(string $prompt): string
    {
        if ($this->englishPrompt !== null) {
            return $this->englishPrompt;
        }
        $this->englishPrompt = $prompt;
        if ((bool) config('ai_media.translate_prompts', true) && preg_match('/[\x{0600}-\x{06FF}]/u', $prompt)) {
            try {
                $english = $this->text->englishImagePrompt($prompt);
                if (is_string($english) && trim($english) !== '') {
                    $this->englishPrompt = trim($english);
                }
            } catch (Throwable) {
                // keep the original prompt
            }
        }

        return $this->englishPrompt;
    }

    private function ensureOk(Response $response, string $label): void
    {
        if ($response->successful()) {
            return;
        }
        $status = $response->status();
        $raw = $response->json('errors.0.message') ?? $response->json('error.message') ?? $response->json('error');
        $detail = is_string($raw) ? trim($raw) : '';
        $message = match (true) {
            $status === 401 || $status === 403 => "مفتاح {$label} غير صالح أو بدون صلاحية.",
            $status === 429 => "تم تجاوز الحصة المجانية لدى {$label}.",
            $status === 503 => "{$label} مشغول أو الموديل قيد التحميل.",
            default => "{$label} رفض الطلب ({$status})" . ($detail !== '' ? ': ' . Str::limit($detail, 160, '…') : '.'),
        };

        throw new RuntimeException($message);
    }

    private function mimeOf(Response $response): string
    {
        $mime = strtolower(trim(explode(';', (string) $response->header('Content-Type'))[0]));

        return $mime !== '' ? $mime : 'image/png';
    }

    private function store(string $bytes, string $mime, int $userId, int $ticketId, string $provider, string $model, bool $edited): array
    {
        if ($bytes === '') {
            throw new RuntimeException('مزود الصور رجع ملفًا فارغًا.');
        }
        $extension = match (true) {
            str_contains($mime, 'jpeg'), str_contains($mime, 'jpg') => 'jpg',
            str_contains($mime, 'webp') => 'webp',
            default => 'png',
        };
        $path = 'assistant/generated/' . $userId . '/' . $ticketId . '/' . Str::uuid() . '.' . $extension;
        Storage::disk('local')->put($path, $bytes);

        return [
            'path' => $path,
            'absolute_path' => Storage::disk('local')->path($path),
            'name' => ($edited ? 'AI-Edited-Image-' : 'AI-Generated-Image-') . now()->format('Ymd-His') . '.' . $extension,
            'mime' => $mime,
            'size' => strlen($bytes),
            'model' => $model,
            'provider' => $provider,
            'usage' => null,
        ];
    }
}
