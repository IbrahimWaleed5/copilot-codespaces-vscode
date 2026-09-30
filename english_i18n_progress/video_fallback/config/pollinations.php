<?php

/*
|--------------------------------------------------------------------------
| Pollinations API (https://gen.pollinations.ai)
|--------------------------------------------------------------------------
| Endpoints and model ids follow the official API docs (APIDOCS.md in
| github.com/pollinations/pollinations). The secret key (sk_...) lives ONLY
| in the server environment: never in code, Git, API responses or clients.
*/

return [
    'api_key' => env('POLLINATIONS_API_KEY'),
    'base_url' => rtrim((string) env('POLLINATIONS_BASE_URL', 'https://gen.pollinations.ai'), '/'),
    // Separate host used only to give Pollinations a public URL for an input image (image → video).
    'media_url' => rtrim((string) env('POLLINATIONS_MEDIA_URL', 'https://media.pollinations.ai'), '/'),

    // Models (docs defaults). They are checked against the live catalogue (/image/models) before use.
    // When the key is set, Pollinations is added at the end of the image/video provider lists
    // even if AI_IMAGE_PROVIDERS / AI_VIDEO_PROVIDERS were written before it existed.
    'auto_fallback' => (bool) env('POLLINATIONS_AUTO_FALLBACK', true),

    'image_model' => env('POLLINATIONS_IMAGE_MODEL', 'tongyi-mai/z-image-turbo'),
    'edit_model' => env('POLLINATIONS_EDIT_MODEL', 'black-forest-labs/flux.1-kontext-pro'),
    'video_model' => env('POLLINATIONS_VIDEO_MODEL', 'google/veo-3.1-fast'),
    'text_model' => env('POLLINATIONS_TEXT_MODEL', 'openai/gpt-5.4-nano'),
    // Optional stronger text model for the demanding levels (same levels that use GEMINI_PRO_MODEL). Empty = text_model.
    'text_pro_model' => env('POLLINATIONS_PRO_TEXT_MODEL', ''),

    'image_size' => env('POLLINATIONS_IMAGE_SIZE', '1024x768'),
    'video_duration' => (int) env('POLLINATIONS_VIDEO_DURATION', 6),
    'video_aspect_ratio' => env('POLLINATIONS_VIDEO_ASPECT_RATIO', '16:9'),

    // HTTP behaviour
    'timeout' => (int) env('POLLINATIONS_TIMEOUT', 120),        // image / text requests (seconds)
    'video_poll_timeout' => (int) env('POLLINATIONS_VIDEO_POLL_TIMEOUT', 8), // each video check (seconds)
    'retries' => (int) env('POLLINATIONS_RETRIES', 1),          // extra attempts on 500/502/503 / connection errors only (never on 4xx)
    'models_cache_minutes' => (int) env('POLLINATIONS_MODELS_CACHE_MINUTES', 30),
];
