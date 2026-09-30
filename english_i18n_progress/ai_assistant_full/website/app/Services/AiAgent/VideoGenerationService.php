<?php

namespace App\Services\AiAgent;

use App\Models\AiUsageLog;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use App\Services\AiCreditService;
use App\Services\GeminiSupportService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Video generation takes minutes, so it never blocks a request and needs no queue worker:
 * start() launches the job at the provider (Gemini Veo or ComfyUI) and remembers it;
 * advance() is called by the chat's normal message polling, checks the job once, and when the
 * video is ready it is stored and posted into the conversation as an assistant message.
 */
class VideoGenerationService
{
    public function __construct(
        private readonly GeminiSupportService $text,
        private readonly ComfyUiClient $comfy,
        private readonly AiCreditService $credits,
    ) {}

    public function enabled(): bool
    {
        return $this->text->videoAvailable();
    }

    /**
     * @return array{provider:string,handle:string}
     */
    public function start(SupportTicket $ticket, int $userId, string $request, ?AiUsageLog $usage): array
    {
        $prompt = $this->text->englishImagePrompt($request, 'video') ?: $request;
        $errors = [];

        foreach ((array) config('ai_media.video.providers', []) as $provider) {
            try {
                $handle = match ($provider) {
                    'veo' => $this->startVeo($prompt),
                    'comfyui' => $this->comfy->configured('comfy_video_workflow')
                        ? $this->comfy->queue('comfy_video_workflow', $prompt, 'text, watermark, logo, blurry, distorted')
                        : null,
                    default => null,
                };
                if (! $handle) {
                    continue;
                }

                $jobs = $this->jobs($ticket->id);
                $jobs[] = [
                    'id' => (string) Str::uuid(),
                    'provider' => $provider,
                    'handle' => $handle,
                    'user_id' => $userId,
                    'usage_id' => $usage?->id,
                    'started_at' => now()->timestamp,
                ];
                Cache::put($this->key($ticket->id), $jobs, now()->addDay());

                return ['provider' => $provider, 'handle' => $handle];
            } catch (Throwable $e) {
                $errors[$provider] = $e->getMessage();
                Log::warning('Video provider failed to start; trying the next one.', ['provider' => $provider, 'error' => $e->getMessage()]);
            }
        }

        throw new RuntimeException($errors ? (string) reset($errors) : 'لا يوجد مزود فيديو مضبوط على السيرفر.');
    }

    /**
     * Checks this conversation's running videos once (called from message polling).
     * Returns how many videos finished (successfully or not) during this call.
     */
    public function advance(SupportTicket $ticket): int
    {
        $jobs = $this->jobs($ticket->id);
        // Look at most every 8 seconds per conversation, whatever the polling rate is.
        if ($jobs === [] || ! Cache::add($this->key($ticket->id) . ':tick', 1, 8)) {
            return 0;
        }

        $remaining = [];
        $finished = 0;
        $maxSeconds = max(3, (int) config('ai_media.video.max_minutes', 20)) * 60;

        foreach ($jobs as $job) {
            try {
                $result = match ($job['provider']) {
                    'veo' => $this->pollVeo((string) $job['handle']),
                    'comfyui' => $this->comfy->result((string) $job['handle'], ['gifs', 'videos', 'images']),
                    default => ['done' => true, 'error' => 'مزود فيديو غير معروف.'],
                };
            } catch (Throwable $e) {
                Log::notice('Video status check failed; will retry.', ['provider' => $job['provider'], 'error' => $e->getMessage()]);
                $result = ['done' => false];
            }

            if (! ($result['done'] ?? false) && now()->timestamp - (int) $job['started_at'] > $maxSeconds) {
                $result = ['done' => true, 'error' => 'انتهت المهلة قبل أن يجهز الفيديو.'];
            }

            if (! ($result['done'] ?? false)) {
                $remaining[] = $job;
                continue;
            }

            $finished++;
            $this->finish($ticket, $job, $result);
        }

        if ($remaining === []) {
            Cache::forget($this->key($ticket->id));
        } else {
            Cache::put($this->key($ticket->id), $remaining, now()->addDay());
        }

        return $finished;
    }

    public function pendingCount(int $ticketId): int
    {
        return count($this->jobs($ticketId));
    }

    private function startVeo(string $prompt): ?string
    {
        $key = trim((string) config('services.gemini.api_key'));
        if ($key === '') {
            return null;
        }
        $model = (string) config('ai_media.video.veo_model', 'veo-3.1-generate-preview');
        $response = Http::acceptJson()
            ->timeout(60)
            ->withHeaders(['x-goog-api-key' => $key])
            ->post(sprintf('https://generativelanguage.googleapis.com/v1beta/models/%s:predictLongRunning', rawurlencode($model)), [
                'instances' => [['prompt' => $prompt]],
                'parameters' => ['aspectRatio' => (string) config('ai_media.video.aspect_ratio', '16:9')],
            ]);

        if (! $response->successful()) {
            $status = $response->status();
            throw new RuntimeException(match (true) {
                in_array($status, [401, 403], true) => 'Veo غير مفعّل لمفتاح Gemini (يحتاج حسابًا مدفوعًا).',
                $status === 429 => 'تم تجاوز حصة Veo حاليًا.',
                $status === 404 => 'نموذج Veo غير متاح لهذا المفتاح.',
                default => 'رفض Veo الطلب (' . $status . ').',
            });
        }

        $name = (string) $response->json('name', '');
        if ($name === '') {
            throw new RuntimeException('Veo لم يرجع رقم عملية.');
        }

        return $name;
    }

    /** @return array{done:bool,bytes?:string,mime?:string,error?:string} */
    private function pollVeo(string $operation): array
    {
        $key = trim((string) config('services.gemini.api_key'));
        $response = Http::acceptJson()
            ->timeout(20)
            ->withHeaders(['x-goog-api-key' => $key])
            ->get('https://generativelanguage.googleapis.com/v1beta/' . ltrim($operation, '/'));

        if (! $response->successful() || ! $response->json('done')) {
            return ['done' => false];
        }
        if ($response->json('error')) {
            return ['done' => true, 'error' => 'فشل Veo في إنشاء الفيديو: ' . Str::limit((string) $response->json('error.message', ''), 160, '…')];
        }

        $uri = (string) $response->json('response.generateVideoResponse.generatedSamples.0.video.uri', '');
        if ($uri === '') {
            $filtered = $response->json('response.generateVideoResponse.raiMediaFilteredReasons.0');

            return ['done' => true, 'error' => $filtered
                ? 'رفض Veo الطلب بسبب سياسة المحتوى. جرّب وصفًا مختلفًا.'
                : 'Veo أنهى العملية بدون فيديو.'];
        }

        $video = Http::timeout(180)->withHeaders(['x-goog-api-key' => $key])->get($uri);
        if (! $video->successful() || $video->body() === '') {
            return ['done' => false]; // try the download again on the next poll
        }

        return ['done' => true, 'bytes' => $video->body(), 'mime' => 'video/mp4'];
    }

    private function finish(SupportTicket $ticket, array $job, array $result): void
    {
        $usage = ! empty($job['usage_id']) ? AiUsageLog::query()->find($job['usage_id']) : null;

        if (isset($result['error']) || empty($result['bytes'])) {
            if ($usage) {
                try { $this->credits->refund($usage, 'video_generation_failed'); } catch (Throwable) {}
            }
            SupportMessage::create([
                'support_ticket_id' => $ticket->id,
                'sender_id' => null,
                'sender_type' => 'bot',
                'message' => 'تعذر إكمال الفيديو: ' . ($result['error'] ?? 'لم يرجع المزود ملفًا.') . ' تمت إعادة الرصيد المحجوز.',
                'message_type' => 'text',
                'is_internal' => false,
            ]);
            $ticket->forceFill(['last_message_at' => now()])->save();

            return;
        }

        $mime = (string) ($result['mime'] ?? 'video/mp4');
        $extension = match (true) {
            str_contains($mime, 'webm') => 'webm',
            str_contains($mime, 'gif') => 'gif',
            str_starts_with($mime, 'image/') => 'png',
            default => 'mp4',
        };
        $path = 'assistant/generated/' . $job['user_id'] . '/' . $ticket->id . '/' . Str::uuid() . '.' . $extension;
        Storage::disk('local')->put($path, $result['bytes']);

        SupportMessage::create([
            'support_ticket_id' => $ticket->id,
            'sender_id' => null,
            'sender_type' => 'bot',
            'message' => 'تم إنشاء الفيديو وجاهز للمشاهدة والتنزيل.',
            'message_type' => str_starts_with($mime, 'image/') ? 'image' : 'file',
            'is_internal' => false,
            'attachment_path' => $path,
            'attachment_name' => 'AI-Video-' . now()->format('Ymd-His') . '.' . $extension,
            'attachment_mime' => $mime,
            'attachment_size' => strlen($result['bytes']),
            'scan_status' => 'generated',
        ]);
        $ticket->forceFill(['last_message_at' => now()])->save();

        if ($usage) {
            try {
                $this->credits->complete($usage, $job['provider'] === 'veo' ? 'gemini-veo' : 'comfyui',
                    $job['provider'] === 'veo' ? (string) config('ai_media.video.veo_model') : 'comfyui-workflow', 0, 0);
            } catch (Throwable $e) {
                Log::warning('Video credit settlement failed.', ['usage_id' => $usage->id, 'error' => $e->getMessage()]);
            }
        }
    }

    private function jobs(int $ticketId): array
    {
        $jobs = Cache::get($this->key($ticketId), []);

        return is_array($jobs) ? $jobs : [];
    }

    private function key(int $ticketId): string
    {
        return 'ai_video_jobs:ticket:' . $ticketId;
    }
}
