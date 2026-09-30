<?php

namespace App\Services;

use App\Exceptions\PollinationsException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Server-side client for the Pollinations API (https://gen.pollinations.ai).
 *
 * Endpoints follow the official API docs (APIDOCS.md):
 *   GET  /image/models               image + video catalogue (filtered by the key's permissions / paid balance)
 *   POST /v1/images/generations      text → image (b64_json)
 *   POST /v1/images/edits            image + prompt → image (multipart, the file never becomes public)
 *   GET  /video/{prompt}             text/image → video (mp4, synchronous; the same request re-attaches to a running job)
 *   POST /v1/chat/completions        text (OpenAI-compatible)
 *   GET  /account/balance            pollen balance (free call)
 *   POST https://media.pollinations.ai/upload   public URL for an image-to-video start frame
 *
 * Security: the secret key is read from the environment only, sent only as a Bearer header from this
 * server, and never logged, returned in responses, or put in URLs.
 */
class PollinationsService
{
    public function configured(): bool
    {
        return $this->key() !== '';
    }

    // ── Models ───────────────────────────────────────────────────────────────

    /**
     * Image and video models this key can really use (normalised). Cached; an unreachable catalogue is
     * remembered briefly so a slow API never slows every chat message.
     *
     * @return array<int,array{id:string,aliases:array<int,string>,input:array<int,string>,output:array<int,string>,endpoints:array<int,string>,paid_only:bool}>
     */
    public function mediaModels(bool $refresh = false): array
    {
        if (! $this->configured()) {
            return [];
        }
        if (! $refresh) {
            $cached = Cache::get('pollinations:media_models');
            if (is_array($cached)) {
                return $cached;
            }
            if (Cache::has('pollinations:media_models:unavailable')) {
                return [];
            }
        }

        try {
            $response = $this->send('models', fn () => $this->client(12)->get($this->base() . '/image/models'), retries: 0);
            $raw = $response->json();
            $list = is_array($raw) && array_is_list($raw) ? $raw : (array) ($raw['data'] ?? []);
            $models = [];
            foreach ($list as $entry) {
                if (! is_array($entry)) {
                    continue;
                }
                $id = trim((string) ($entry['id'] ?? $entry['name'] ?? ''));
                if ($id === '') {
                    continue;
                }
                $models[] = [
                    'id' => $id,
                    'aliases' => array_values(array_map('strval', (array) ($entry['aliases'] ?? []))),
                    'input' => array_values(array_map('strval', (array) ($entry['input_modalities'] ?? []))),
                    'output' => array_values(array_map('strval', (array) ($entry['output_modalities'] ?? []))),
                    'endpoints' => array_values(array_map('strval', (array) ($entry['supported_endpoints'] ?? []))),
                    'paid_only' => (bool) ($entry['paid_only'] ?? false),
                ];
            }
        } catch (Throwable $e) {
            Cache::put('pollinations:media_models:unavailable', 1, now()->addMinutes(5));

            return [];
        }

        if ($models === []) {
            Cache::put('pollinations:media_models:unavailable', 1, now()->addMinutes(5));

            return [];
        }
        Cache::put('pollinations:media_models', $models, now()->addMinutes(max(1, (int) config('pollinations.models_cache_minutes', 30))));

        return $models;
    }

    /**
     * The model to use for a job, verified against the live catalogue.
     * kind: image | edit | video | image_to_video.
     * Returns the configured model when the catalogue lists it, otherwise the catalogue's first suitable
     * model (the catalogue lists each default first). Video is never returned unverified.
     */
    public function resolveModel(string $kind): ?string
    {
        $wanted = trim((string) match ($kind) {
            'edit' => config('pollinations.edit_model'),
            'video', 'image_to_video' => config('pollinations.video_model'),
            default => config('pollinations.image_model'),
        });

        $candidates = array_values(array_filter($this->mediaModels(), fn (array $m): bool => match ($kind) {
            'image' => in_array('image', $m['output'], true),
            'edit' => in_array('image', $m['output'], true) && in_array('image', $m['input'], true)
                && ($m['endpoints'] === [] || $this->hasEndpoint($m['endpoints'], '/v1/images/edits')),
            'video' => in_array('video', $m['output'], true),
            'image_to_video' => in_array('video', $m['output'], true) && in_array('image', $m['input'], true),
            default => false,
        }));

        if ($candidates === []) {
            // Catalogue unreachable: images may still use the documented default; video must be verified.
            return in_array($kind, ['image', 'edit'], true) && $this->mediaModels() === [] && $wanted !== '' ? $wanted : null;
        }

        foreach ($candidates as $model) {
            if ($wanted !== '' && ($model['id'] === $wanted || in_array($wanted, $model['aliases'], true))) {
                return $model['id'];
            }
        }

        return $candidates[0]['id'];
    }

    public function supportsVideo(bool $fromImage = false): bool
    {
        return $this->configured() && $this->resolveModel($fromImage ? 'image_to_video' : 'video') !== null;
    }

    // ── Images ───────────────────────────────────────────────────────────────

    /** @return array{bytes:string,mime:string,model:string,usage:?array} */
    public function generateImage(string $prompt, ?string $size = null): array
    {
        $this->assertConfigured();
        $model = $this->resolveModel('image') ?? throw new PollinationsException('لا يوجد موديل صور متاح حاليًا.', 'unsupported_model');
        $payload = [
            'prompt' => $this->clip($prompt, 32000),
            'model' => $model,
            'n' => 1,
            'size' => $this->size($size),
            'response_format' => 'b64_json',
        ];

        $response = $this->send('image', fn () => $this->client($this->timeout())->post($this->base() . '/v1/images/generations', $payload));

        return $this->decodeImage($response, $model);
    }

    /**
     * Edits/redesigns an existing image. Sent as multipart so the user's file is not published anywhere.
     *
     * @return array{bytes:string,mime:string,model:string,usage:?array}
     */
    public function editImage(string $path, string $mime, string $prompt): array
    {
        $this->assertConfigured();
        if (! is_file($path) || ! is_readable($path)) {
            throw new PollinationsException('الصورة المرفقة غير متاحة للتعديل.', 'bad_request');
        }
        $model = $this->resolveModel('edit') ?? throw new PollinationsException('لا يوجد موديل متاح لتعديل الصور حاليًا.', 'unsupported_model');
        $bytes = (string) file_get_contents($path);
        $name = 'input.' . (str_contains($mime, 'png') ? 'png' : (str_contains($mime, 'webp') ? 'webp' : 'jpg'));

        $response = $this->send('image_edit', fn () => $this->client($this->timeout())
            ->attach('image', $bytes, $name, ['Content-Type' => $mime])
            ->post($this->base() . '/v1/images/edits', [
                'prompt' => $this->clip($prompt, 32000),
                'model' => $model,
                'n' => '1',
                'response_format' => 'b64_json',
            ]));

        return $this->decodeImage($response, $model);
    }

    // ── Video ────────────────────────────────────────────────────────────────

    /**
     * Fixed parameters of one video job. The docs say: after a timeout, repeat the SAME request
     * (same endpoint, prompt, query and seed) and it waits for the generation already running.
     *
     * @return array{prompt:string,query:array<string,mixed>,model:string}
     */
    public function videoJob(string $prompt, ?string $startFrameUrl = null): array
    {
        $this->assertConfigured();
        $kind = $startFrameUrl ? 'image_to_video' : 'video';
        $model = $this->resolveModel($kind)
            ?? throw new PollinationsException('لا يوجد موديل فيديو متاح لحساب الخدمة حاليًا.', 'unsupported_model');

        $query = [
            'model' => $model,
            'duration' => $this->duration($model),
            'aspectRatio' => (string) config('pollinations.video_aspect_ratio', '16:9'),
            'seed' => random_int(1, 2_000_000_000),
        ];
        if ($startFrameUrl) {
            $query['image'] = $startFrameUrl;
        }

        // The prompt travels in the URL path, so keep it to a sane length.
        return ['prompt' => $this->clip($prompt, 1500), 'query' => $query, 'model' => $model];
    }

    /**
     * Asks for the video once, waiting at most $timeout seconds.
     * done=false: still generating (the request timed out, which is normal for video).
     *
     * @param array{prompt:string,query:array<string,mixed>} $job
     * @return array{done:bool,bytes?:string,mime?:string}
     */
    public function fetchVideo(array $job, ?int $timeout = null): array
    {
        $this->assertConfigured();
        $timeout = $timeout ?? max(3, (int) config('pollinations.video_poll_timeout', 8));
        $url = $this->base() . '/video/' . rawurlencode((string) $job['prompt']);

        try {
            $response = $this->send('video', fn () => Http::withToken($this->key())
                ->withHeaders(['Accept' => 'video/mp4, application/json'])
                ->connectTimeout(10)
                ->timeout($timeout)
                ->get($url, (array) $job['query']), retries: 0, timeoutIsFailure: false);
        } catch (PollinationsException $e) {
            if ($e->reason === 'timeout') {
                return ['done' => false];
            }
            throw $e;
        }

        $bytes = $response->body();
        $mime = $this->sniff($bytes) ?? strtolower(trim(explode(';', (string) $response->header('Content-Type'))[0]));
        if (! str_starts_with($mime, 'video/') || strlen($bytes) < 1024) {
            throw new PollinationsException('خدمة الفيديو رجعت ملفًا غير صالح.', 'invalid_response', $response->status());
        }

        return ['done' => true, 'bytes' => $bytes, 'mime' => $mime];
    }

    /**
     * Gives the video model a URL for the start frame. NOTE: media.pollinations.ai URLs are public
     * (unlisted) for 30 days, so this is only used when the user asks to animate their image.
     */
    public function uploadMedia(string $path, string $mime): string
    {
        $this->assertConfigured();
        if (! is_file($path)) {
            throw new PollinationsException('الصورة المرفقة غير متاحة.', 'bad_request');
        }
        $bytes = (string) file_get_contents($path);
        $response = $this->send('upload', fn () => $this->client(60)
            ->attach('file', $bytes, 'frame.' . (str_contains($mime, 'png') ? 'png' : 'jpg'), ['Content-Type' => $mime])
            ->post($this->mediaBase() . '/upload'));

        $url = (string) $response->json('url', '');
        $host = strtolower((string) parse_url($url, PHP_URL_HOST));
        if (! str_starts_with($url, 'https://') || ! ($host === 'pollinations.ai' || str_ends_with($host, '.pollinations.ai'))) {
            throw new PollinationsException('تعذر تجهيز الصورة للفيديو.', 'invalid_response', $response->status());
        }

        return $url;
    }

    // ── Text ─────────────────────────────────────────────────────────────────

    /**
     * OpenAI-compatible chat. Usage is returned in the same shape as Gemini's usageMetadata so the
     * existing metered Credit billing works unchanged.
     *
     * @param array<int,array{role:string,content:string}> $messages
     * @param array{model?:string,max_tokens?:int,temperature?:float,reasoning?:string,timeout?:int} $options
     * @return array{text:string,usage:?array,model:string}
     */
    public function chat(array $messages, array $options = []): array
    {
        $this->assertConfigured();
        $model = trim((string) ($options['model'] ?? config('pollinations.text_model', 'openai/gpt-5.4-nano')));
        $payload = array_filter([
            'model' => $model,
            'messages' => $messages,
            'max_tokens' => isset($options['max_tokens']) ? max(1, (int) $options['max_tokens']) : null,
            'temperature' => $options['temperature'] ?? null,
            'reasoning_effort' => $options['reasoning'] ?? null,
        ], static fn ($v) => $v !== null);

        $response = $this->send('text', fn () => $this->client((int) ($options['timeout'] ?? $this->timeout()))
            ->post($this->base() . '/v1/chat/completions', $payload));

        $content = $response->json('choices.0.message.content');
        if (is_array($content)) {
            $content = collect($content)->map(fn ($p) => is_array($p) ? ($p['text'] ?? '') : (string) $p)->implode('');
        }
        $text = trim((string) $content);
        if ($text === '') {
            throw new PollinationsException('خدمة النصوص رجعت ردًا فارغًا.', 'invalid_response', $response->status());
        }

        return ['text' => $text, 'usage' => $this->textUsage($response->json('usage'), $model), 'model' => $model];
    }

    /** @return array{balance:float,paid:?float,tier:?float}|null  null when the key may not read it */
    public function balance(): ?array
    {
        if (! $this->configured()) {
            return null;
        }
        try {
            $response = $this->send('balance', fn () => $this->client(15)->get($this->base() . '/account/balance'), retries: 0);
        } catch (PollinationsException $e) {
            if ($e->reason === 'forbidden') {
                return null; // unbudgeted key without account:usage: allowed by the docs
            }
            throw $e;
        }

        return [
            'balance' => (float) $response->json('balance', 0),
            'paid' => is_numeric($response->json('accountBalance.paid')) ? (float) $response->json('accountBalance.paid') : null,
            'tier' => is_numeric($response->json('accountBalance.tier')) ? (float) $response->json('accountBalance.tier') : null,
        ];
    }

    // ── HTTP plumbing ────────────────────────────────────────────────────────

    /**
     * Runs a request with limited retries (connection errors and 500/502/503 only), a short cooldown
     * after 429, and safe errors. Nothing that could contain the key is ever logged.
     */
    private function send(string $action, callable $call, ?int $retries = null, bool $timeoutIsFailure = true): Response
    {
        $cooldownKey = 'pollinations:cooldown:' . $action;
        if (($until = Cache::get($cooldownKey)) && $until > time()) {
            throw new PollinationsException('خدمة التوليد مشغولة الآن. حاول بعد ' . ($until - time()) . ' ثانية.', 'rate_limited', 429, $until - time());
        }

        $attempts = 1 + max(0, min(3, $retries ?? (int) config('pollinations.retries', 1)));
        for ($attempt = 1; ; $attempt++) {
            try {
                /** @var Response $response */
                $response = $call();
            } catch (ConnectionException $e) {
                $isTimeout = stripos($e->getMessage(), 'timed out') !== false || stripos($e->getMessage(), 'timeout') !== false;
                if ($attempt < $attempts && ($timeoutIsFailure || ! $isTimeout)) {
                    usleep(300_000 * $attempt);
                    continue;
                }
                if ($timeoutIsFailure || ! $isTimeout) {
                    Log::warning('Pollinations request failed.', ['action' => $action, 'reason' => $isTimeout ? 'timeout' : 'connection']);
                }
                throw new PollinationsException(
                    $isTimeout ? 'انتهت مهلة خدمة التوليد قبل أن ترد.' : 'تعذر الاتصال بخدمة التوليد.',
                    $isTimeout ? 'timeout' : 'unavailable'
                );
            }

            if ($response->successful()) {
                return $response;
            }
            if (in_array($response->status(), [500, 502, 503], true) && $attempt < $attempts) {
                usleep(400_000 * $attempt);
                continue;
            }

            $error = $this->errorFrom($response);
            if ($error->reason === 'rate_limited') {
                Cache::put($cooldownKey, time() + $error->retryAfter, $error->retryAfter);
            }
            Log::warning('Pollinations request failed.', [
                'action' => $action,
                'status' => $response->status(),
                'reason' => $error->reason,
                'request_id' => $error->requestId,
            ]);

            throw $error;
        }
    }

    private function errorFrom(Response $response): PollinationsException
    {
        $status = $response->status();
        $code = (string) ($response->json('error.code') ?? '');
        $requestId = $response->json('error.requestId');
        $requestId = is_string($requestId) ? substr($requestId, 0, 80) : null;
        $retryAfter = null;

        [$reason, $message] = match (true) {
            $status === 401 => ['auth', 'مفتاح خدمة التوليد غير صالح أو غير مضبوط على السيرفر.'],
            $status === 402 => ['payment', 'رصيد خدمة التوليد نفد حاليًا. جرّب لاحقًا.'],
            $status === 403 => ['forbidden', 'هذا النوع من التوليد غير متاح لحساب الخدمة حاليًا.'],
            $status === 422 && $code === 'content_policy_violation' => ['content_policy', 'رُفض الطلب بسبب سياسة المحتوى. عدّل الوصف وحاول مجددًا.'],
            $status === 422 => ['unprocessable', 'الموديل رفض هذا الطلب. جرّب وصفًا أو إعدادات مختلفة.'],
            $status === 429 => ['rate_limited', 'خدمة التوليد مزدحمة الآن. حاول بعد قليل.'],
            $status === 400 && $code === 'image_too_large' => ['bad_request', 'الصورة كبيرة جدًا للمعالجة.'],
            $status === 400 => ['bad_request', 'طلب غير صالح لخدمة التوليد.'],
            $status === 404 => ['not_found', 'الموديل أو المسار غير موجود لدى خدمة التوليد.'],
            $status === 503 => ['unavailable', 'خدمة التوليد غير متاحة مؤقتًا.'],
            default => ['upstream', 'خدمة التوليد واجهت خطأ مؤقتًا (' . $status . ').'],
        };
        if ($reason === 'rate_limited') {
            $header = (string) $response->header('Retry-After');
            $retryAfter = max(5, min(600, is_numeric($header) ? (int) $header : 30));
        }

        return new PollinationsException($message, $reason, $status, $retryAfter, $requestId);
    }

    /** @return array{bytes:string,mime:string,model:string,usage:?array} */
    private function decodeImage(Response $response, string $model): array
    {
        $b64 = (string) $response->json('data.0.b64_json', '');
        $bytes = $b64 !== '' ? base64_decode($b64, true) : false;

        if (! $bytes) {
            // Some models may still answer with a stored URL; only our provider's media host is fetched.
            $url = (string) $response->json('data.0.url', '');
            $host = strtolower((string) parse_url($url, PHP_URL_HOST));
            if (str_starts_with($url, 'https://') && ($host === 'pollinations.ai' || str_ends_with($host, '.pollinations.ai'))) {
                $file = Http::timeout(60)->get($url);
                $bytes = $file->successful() ? $file->body() : false;
            }
        }

        $mime = is_string($bytes) ? $this->sniff($bytes) : null;
        if (! is_string($bytes) || $bytes === '' || $mime === null || ! str_starts_with($mime, 'image/')
            || strlen($bytes) > 30 * 1024 * 1024 || ($mime !== 'image/svg+xml' && @getimagesizefromstring($bytes) === false)) {
            throw new PollinationsException('خدمة الصور رجعت ملفًا غير صالح.', 'invalid_response', $response->status());
        }

        $usage = $response->json('usage');

        return ['bytes' => $bytes, 'mime' => $mime, 'model' => $model, 'usage' => is_array($usage) ? $usage : null];
    }

    private function textUsage(mixed $raw, string $model): ?array
    {
        if (! is_array($raw)) {
            return null;
        }
        $prompt = (int) ($raw['prompt_tokens'] ?? 0);
        $completion = (int) ($raw['completion_tokens'] ?? 0);
        $reasoning = (int) ($raw['reasoning_tokens'] ?? $raw['completion_tokens_details']['reasoning_tokens'] ?? 0);
        $cached = (int) ($raw['prompt_tokens_details']['cached_tokens'] ?? $raw['cached_input_tokens'] ?? 0);

        return [
            'model' => 'pollinations:' . $model,
            'promptTokenCount' => $prompt,
            'cachedContentTokenCount' => min($prompt, $cached),
            'candidatesTokenCount' => max(0, $completion - $reasoning),
            'thoughtsTokenCount' => $reasoning,
            'totalTokenCount' => (int) ($raw['total_tokens'] ?? ($prompt + $completion)),
        ];
    }

    private function sniff(string $bytes): ?string
    {
        if ($bytes === '') {
            return null;
        }
        $mime = (new \finfo(FILEINFO_MIME_TYPE))->buffer($bytes);

        return is_string($mime) && $mime !== '' && $mime !== 'application/octet-stream' ? strtolower($mime) : null;
    }

    private function client(int $timeout): PendingRequest
    {
        return Http::withToken($this->key())
            ->acceptJson()
            ->connectTimeout(10)
            ->timeout(max(5, $timeout));
    }

    private function assertConfigured(): void
    {
        if (! $this->configured()) {
            throw new PollinationsException('خدمة التوليد الإضافية غير مضبوطة على السيرفر.', 'not_configured');
        }
    }

    private function duration(string $model): int
    {
        $seconds = max(1, min(120, (int) config('pollinations.video_duration', 6)));
        $id = strtolower($model);

        // Documented per-model limits (APIDOCS: `duration`).
        return match (true) {
            str_contains($id, 'veo') => $seconds <= 4 ? 4 : ($seconds <= 6 ? 6 : 8),
            str_contains($id, 'seedance-2.5') => 4,
            str_contains($id, 'wan-3.0'), $id === 'minimax/minimax-h3' => 5,
            str_contains($id, 'nova-reel') => max(6, (int) (round($seconds / 6) * 6)),
            default => min($seconds, 10),
        };
    }

    private function size(?string $size): string
    {
        $size = trim((string) ($size ?? config('pollinations.image_size', '1024x768')));

        return preg_match('/^\d{3,4}x\d{3,4}$/', $size) ? $size : '1024x1024';
    }

    private function hasEndpoint(array $endpoints, string $path): bool
    {
        foreach ($endpoints as $endpoint) {
            if (str_contains((string) $endpoint, $path)) {
                return true;
            }
        }

        return false;
    }

    private function clip(string $text, int $max): string
    {
        return mb_substr(trim($text), 0, $max);
    }

    private function timeout(): int
    {
        return max(10, (int) config('pollinations.timeout', 120));
    }

    private function key(): string
    {
        return trim((string) config('pollinations.api_key', ''));
    }

    private function base(): string
    {
        return rtrim((string) config('pollinations.base_url', 'https://gen.pollinations.ai'), '/');
    }

    private function mediaBase(): string
    {
        return rtrim((string) config('pollinations.media_url', 'https://media.pollinations.ai'), '/');
    }
}
