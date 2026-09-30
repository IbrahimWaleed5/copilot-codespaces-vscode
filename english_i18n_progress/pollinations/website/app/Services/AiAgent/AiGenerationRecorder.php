<?php

namespace App\Services\AiAgent;

use App\Models\AiGeneration;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

/**
 * Keeps the ai_generations record of every image/video request. Never breaks the request:
 * if the table is missing (migration not run yet) or a write fails, generation continues.
 */
class AiGenerationRecorder
{
    /** @param array<string,mixed> $attributes */
    public function start(array $attributes): ?AiGeneration
    {
        if (! $this->ready()) {
            return null;
        }
        try {
            return AiGeneration::create([
                'status' => AiGeneration::PROCESSING,
                'prompt' => Str::limit((string) ($attributes['prompt'] ?? ''), 8000, ''),
            ] + $attributes);
        } catch (Throwable $e) {
            Log::notice('AI generation record could not be created.', ['error' => $e->getMessage()]);

            return null;
        }
    }

    /** @param array{path?:string,mime?:string,size?:int,provider?:string,model?:string} $artifact */
    public function complete(?AiGeneration $generation, array $artifact, ?int $messageId = null, array $metadata = []): void
    {
        if (! $generation) {
            return;
        }
        try {
            $generation->forceFill([
                'status' => AiGeneration::COMPLETED,
                'provider' => $artifact['provider'] ?? $generation->provider,
                'model' => isset($artifact['model']) ? Str::limit((string) $artifact['model'], 120, '') : $generation->model,
                'output_path' => $artifact['path'] ?? null,
                'output_mime' => $artifact['mime'] ?? null,
                'output_size' => isset($artifact['size']) ? (int) $artifact['size'] : null,
                'support_message_id' => $messageId,
                'metadata' => array_merge((array) $generation->metadata, $this->safe($metadata)),
                'completed_at' => now(),
                'error_code' => null,
                'error_message' => null,
            ])->save();
        } catch (Throwable $e) {
            Log::notice('AI generation record could not be completed.', ['id' => $generation->id, 'error' => $e->getMessage()]);
        }
    }

    public function fail(?AiGeneration $generation, string $reason, ?string $code = null, ?int $messageId = null): void
    {
        if (! $generation) {
            return;
        }
        try {
            $generation->forceFill([
                'status' => AiGeneration::FAILED,
                'error_code' => $code ? Str::limit($code, 40, '') : null,
                'error_message' => Str::limit($this->scrub($reason), 480, '…'),
                'support_message_id' => $messageId ?? $generation->support_message_id,
                'completed_at' => now(),
            ])->save();
        } catch (Throwable $e) {
            Log::notice('AI generation record could not be marked failed.', ['id' => $generation->id, 'error' => $e->getMessage()]);
        }
    }

    public function find(?int $id): ?AiGeneration
    {
        return $id && $this->ready() ? AiGeneration::query()->find($id) : null;
    }

    public static function typeFor(string $tool, bool $hasImage): string
    {
        return $tool === 'video'
            ? ($hasImage ? 'image_to_video' : 'text_to_video')
            : ($hasImage ? 'image_to_image' : 'text_to_image');
    }

    /** Engineering service the request belongs to (drives the prompt style and the record). */
    public static function kindFor(string $prompt, bool $hasImage): string
    {
        $p = Str::lower($prompt);

        return match (true) {
            $hasImage && (bool) preg_match('/(?:حسن|حسّن|تحسين|جودة|وضوح|ارفع|enhance|upscale|improve|sharpen)/u', $p) => 'enhance',
            $hasImage && (bool) preg_match('/(?:اعاد[هة]\s*تصميم|أعد\s*تصميم|اعد\s*تصميم|غير|غيّر|بدل|بدّل|redesign|restyle|makeover)/u', $p) => 'redesign',
            (bool) preg_match('/(?:لاندسكيب|تنسيق\s*(?:حدائق|الحديق|خارجي)|حديق|landscape|garden|pool\s*area)/u', $p) => 'landscape',
            (bool) preg_match('/(?:داخلي|انتيري|انتريور|غرف[ةه]|صالة|صالون|مطبخ|حمام|interior|living\s*room|bedroom|kitchen|walkthrough)/u', $p) => 'interior',
            (bool) preg_match('/(?:خارجي|واجه[ةه]|فيلا|عمار[ةه]|مبنى|exterior|facade|façade|elevation|cinematic)/u', $p) => 'exterior',
            (bool) preg_match('/(?:معماري|رندر|منظور|architect|render|building|house|بيت|منزل)/u', $p) => 'architectural',
            default => 'general',
        };
    }

    /** English style hint added to provider prompts for each engineering service. */
    public static function styleHint(string $kind, bool $video = false): string
    {
        return match ($kind) {
            'architectural' => 'Professional architectural visualization, photorealistic render, accurate proportions, realistic materials and lighting.',
            'interior' => $video
                ? 'Smooth interior walkthrough, steady gimbal camera moving through the space, natural light, realistic materials.'
                : 'Interior design visualization, photorealistic, natural daylight, realistic materials and furniture, wide-angle lens.',
            'exterior' => $video
                ? 'Cinematic exterior architectural shot, slow drone orbit, golden-hour light, realistic landscaping context.'
                : 'Exterior architectural rendering, photorealistic, daylight, realistic landscaping context, eye-level or aerial perspective.',
            'landscape' => 'Landscape architecture rendering, photorealistic vegetation, hardscape and water features, natural light.',
            'enhance' => 'Enhance this render: higher realism, better lighting and shadows, sharper details and textures. Keep exactly the same design, layout and camera angle.',
            'redesign' => 'Redesign as requested while keeping the same space, structure and camera angle; photorealistic result.',
            default => '',
        };
    }

    private function ready(): bool
    {
        static $ready = null;
        if ($ready === null) {
            try {
                $ready = Schema::hasTable('ai_generations');
            } catch (Throwable) {
                $ready = false;
            }
        }

        return $ready;
    }

    private function safe(array $metadata): array
    {
        return collect($metadata)
            ->reject(fn ($v, $k) => preg_match('/key|token|secret|authorization|password/i', (string) $k))
            ->map(fn ($v) => is_string($v) ? Str::limit($this->scrub($v), 300, '…') : $v)
            ->all();
    }

    /** Removes anything that looks like a credential from a message before it is stored. */
    private function scrub(string $text): string
    {
        return (string) preg_replace('/\b(?:sk|pk)_[A-Za-z0-9_\-]{6,}|Bearer\s+\S+/u', '[redacted]', $text);
    }
}
