<?php

namespace App\Console\Commands;

use App\Exceptions\PollinationsException;
use App\Services\AiAgent\AiGenerationRecorder;
use App\Services\PollinationsService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/** Generates ONE small image, stores it in platform storage and (with --user) writes an ai_generations row. */
class PollinationsTestImage extends Command
{
    protected $signature = 'pollinations:test-image
        {prompt? : English prompt}
        {--size=512x512 : Small size to spend as little as possible}
        {--user= : User id to write a test ai_generations record for}';

    protected $description = 'Generate one test image through Pollinations and save it to storage.';

    public function handle(PollinationsService $pollinations, AiGenerationRecorder $recorder): int
    {
        $prompt = (string) ($this->argument('prompt') ?: 'Modern two-storey villa exterior, white stone facade, photorealistic architectural render, daylight');
        $userId = $this->option('user') ? (int) $this->option('user') : null;
        $generation = $userId ? $recorder->start([
            'user_id' => $userId,
            'type' => 'text_to_image',
            'kind' => AiGenerationRecorder::kindFor($prompt, false),
            'provider' => 'pollinations',
            'prompt' => $prompt,
            'metadata' => ['source' => 'artisan_test'],
        ]) : null;

        try {
            $result = $pollinations->generateImage($prompt, (string) $this->option('size'));
        } catch (PollinationsException $e) {
            $recorder->fail($generation, $e->getMessage(), $e->reason);
            $this->error('Failed: ' . $e->reason . ' (HTTP ' . $e->status . ') — ' . $e->getMessage());

            return self::FAILURE;
        }

        $extension = str_contains($result['mime'], 'png') ? 'png' : (str_contains($result['mime'], 'webp') ? 'webp' : 'jpg');
        $path = 'assistant/tests/' . Str::uuid() . '.' . $extension;
        Storage::disk('local')->put($path, $result['bytes']);
        $recorder->complete($generation, ['path' => $path, 'mime' => $result['mime'], 'size' => strlen($result['bytes']), 'provider' => 'pollinations', 'model' => $result['model']]);

        $this->info('OK: ' . $result['model'] . ', ' . $result['mime'] . ', ' . strlen($result['bytes']) . ' bytes');
        $this->line('Saved: ' . Storage::disk('local')->path($path) . ($generation ? ' — ai_generations #' . $generation->id : ''));

        return self::SUCCESS;
    }
}
