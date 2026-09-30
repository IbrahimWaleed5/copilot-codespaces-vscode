<?php

namespace App\Console\Commands;

use App\Exceptions\PollinationsException;
use App\Services\PollinationsService;
use Illuminate\Console\Command;

/** Free checks: key present, catalogue reachable, which models this key can use, balance. */
class PollinationsCheck extends Command
{
    protected $signature = 'pollinations:check {--text : Also send one tiny text request (costs a negligible amount)}';

    protected $description = 'Check the Pollinations connection, key, available models and balance (no image/video is generated).';

    public function handle(PollinationsService $pollinations): int
    {
        if (! $pollinations->configured()) {
            $this->error('POLLINATIONS_API_KEY is not set on this server.');

            return self::FAILURE;
        }
        $this->info('Key: set (value hidden). Base URL: ' . config('pollinations.base_url'));

        try {
            $balance = $pollinations->balance();
            $this->line($balance === null
                ? 'Balance: not readable with this key (allowed for unbudgeted keys) — authentication OK.'
                : sprintf('Balance: %s pollen%s', $balance['balance'], $balance['paid'] !== null ? " (paid: {$balance['paid']}, quest: {$balance['tier']})" : ''));
        } catch (PollinationsException $e) {
            $this->error('Balance/auth check failed: ' . $e->reason . ' (HTTP ' . $e->status . ')');
            if ($e->reason === 'auth') {
                return self::FAILURE;
            }
        }

        $models = $pollinations->mediaModels(true);
        $this->line('Image/video models visible to this key: ' . count($models));
        $videos = array_values(array_filter($models, fn ($m) => in_array('video', $m['output'], true)));
        $this->table(['Use', 'Model (verified)'], [
            ['Text → image', $pollinations->resolveModel('image') ?? '— none'],
            ['Image → image (edit)', $pollinations->resolveModel('edit') ?? '— none'],
            ['Text → video', $pollinations->resolveModel('video') ?? '— none'],
            ['Image → video', $pollinations->resolveModel('image_to_video') ?? '— none'],
        ]);
        if ($videos !== []) {
            $this->line('Video models: ' . implode(', ', array_map(fn ($m) => $m['id'] . ($m['paid_only'] ? ' (paid)' : ''), $videos)));
        }

        if ($this->option('text')) {
            try {
                $result = $pollinations->chat([['role' => 'user', 'content' => 'Reply with the single word: OK']], ['max_tokens' => 10]);
                $this->info('Text OK (' . $result['model'] . '): ' . $result['text']);
            } catch (PollinationsException $e) {
                $this->error('Text failed: ' . $e->reason . ' (HTTP ' . $e->status . ')');

                return self::FAILURE;
            }
        }

        return self::SUCCESS;
    }
}
