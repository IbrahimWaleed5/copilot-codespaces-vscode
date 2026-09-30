<?php

namespace App\Console\Commands;

use App\Exceptions\PollinationsException;
use App\Services\PollinationsService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * MANUAL test only (video costs more). Generates one short video and saves it to storage.
 * Uses the documented pattern: repeat the same request after a timeout until the video is ready.
 */
class PollinationsTestVideo extends Command
{
    protected $signature = 'pollinations:test-video
        {prompt? : English prompt}
        {--image= : Public https URL of a start frame (image → video)}
        {--wait=600 : Maximum seconds to wait}';

    protected $description = 'MANUAL: generate one short test video through Pollinations (spends pollen).';

    public function handle(PollinationsService $pollinations): int
    {
        $prompt = (string) ($this->argument('prompt') ?: 'Slow cinematic drone orbit around a modern white villa at golden hour, photorealistic');
        if (! $this->confirm('This generates a real video and spends pollen. Continue?', true)) {
            return self::SUCCESS;
        }

        try {
            $job = $pollinations->videoJob($prompt, $this->option('image') ?: null);
            $this->line('Model: ' . $job['model'] . ', duration: ' . $job['query']['duration'] . 's');
            $deadline = time() + max(60, (int) $this->option('wait'));
            do {
                $result = $pollinations->fetchVideo($job, 25);
                if ($result['done']) {
                    $path = 'assistant/tests/' . Str::uuid() . '.mp4';
                    Storage::disk('local')->put($path, $result['bytes']);
                    $this->info('OK: ' . strlen($result['bytes']) . ' bytes → ' . Storage::disk('local')->path($path));

                    return self::SUCCESS;
                }
                $this->line('… still generating');
            } while (time() < $deadline);
        } catch (PollinationsException $e) {
            $this->error('Failed: ' . $e->reason . ' (HTTP ' . $e->status . ') — ' . $e->getMessage());

            return self::FAILURE;
        }

        $this->warn('Not ready within the wait time. Running the command again starts a new job (new seed); use a larger --wait.');

        return self::FAILURE;
    }
}
