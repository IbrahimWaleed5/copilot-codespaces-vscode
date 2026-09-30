<?php

/*
|--------------------------------------------------------------------------
| AI media providers (images + video)
|--------------------------------------------------------------------------
| Gemini stays the main provider. The others are tried in order when the
| previous one is not configured, out of quota, or fails. A provider with
| no key/URL in .env is skipped automatically.
*/

$list = static fn (string $value): array => array_values(array_filter(array_map('trim', explode(',', $value))));

return [
    // Order of image providers. Remove a name to disable it. "pollinations" needs POLLINATIONS_API_KEY.
    'image_providers' => $list((string) env('AI_IMAGE_PROVIDERS', 'gemini,pollinations,cloudflare,huggingface,self_hosted')),

    // Abuse protection per user, on top of Credits and the route throttle (0 = no extra limit).
    'rate_limits' => [
        'images_per_hour' => (int) env('AI_IMAGES_PER_HOUR', 30),
        'videos_per_hour' => (int) env('AI_VIDEOS_PER_HOUR', 4),
    ],

    // FLUX / Stable Diffusion work best with English prompts: Gemini rewrites the request first.
    'translate_prompts' => (bool) env('AI_IMAGE_TRANSLATE_PROMPTS', true),

    'cloudflare' => [
        'account_id' => env('CLOUDFLARE_ACCOUNT_ID'),
        'api_token' => env('CLOUDFLARE_AI_TOKEN'),
        'image_model' => env('CLOUDFLARE_IMAGE_MODEL', '@cf/black-forest-labs/flux-1-schnell'),
        'steps' => (int) env('CLOUDFLARE_IMAGE_STEPS', 8),
        'timeout' => (int) env('CLOUDFLARE_TIMEOUT', 90),
    ],

    'huggingface' => [
        'token' => env('HUGGINGFACE_TOKEN'),
        'image_model' => env('HUGGINGFACE_IMAGE_MODEL', 'black-forest-labs/FLUX.1-schnell'),
        // "auto" = ask the Hub which provider serves the model (hf-inference, nscale, fal-ai), or force one of them.
        'provider' => env('HUGGINGFACE_PROVIDER', 'auto'),
        'base_url' => rtrim((string) env('HUGGINGFACE_BASE_URL', 'https://router.huggingface.co/hf-inference/models'), '/'),
        'timeout' => (int) env('HUGGINGFACE_TIMEOUT', 120),
    ],

    // Your own GPU server: AUTOMATIC1111/Forge (driver "a1111") or ComfyUI (driver "comfyui").
    'self_hosted' => [
        'driver' => env('SELF_HOSTED_IMAGE_DRIVER', 'a1111'),
        'url' => rtrim((string) env('SELF_HOSTED_IMAGE_URL', ''), '/'),
        'token' => env('SELF_HOSTED_IMAGE_TOKEN'),
        'width' => (int) env('SELF_HOSTED_IMAGE_WIDTH', 1024),
        'height' => (int) env('SELF_HOSTED_IMAGE_HEIGHT', 768),
        'steps' => (int) env('SELF_HOSTED_IMAGE_STEPS', 28),
        'timeout' => (int) env('SELF_HOSTED_TIMEOUT', 180),
        // ComfyUI workflows exported with "Save (API Format)". Put {{PROMPT}}, {{NEGATIVE}} and {{SEED}} where the values go.
        'comfy_image_workflow' => env('COMFYUI_IMAGE_WORKFLOW', storage_path('app/comfyui/image-workflow.json')),
        'comfy_video_workflow' => env('COMFYUI_VIDEO_WORKFLOW', storage_path('app/comfyui/video-workflow.json')),
    ],

    'video' => [
        // "veo" = Gemini Veo (paid), "pollinations" = Pollinations video models (verified live),
        // "comfyui" = your ComfyUI server with a video workflow.
        'providers' => $list((string) env('AI_VIDEO_PROVIDERS', 'veo,pollinations,comfyui')),
        'enabled' => (bool) env('AI_VIDEO_ENABLED', true),
        'veo_model' => env('GEMINI_VIDEO_MODEL', 'veo-3.1-generate-preview'),
        'aspect_ratio' => env('AI_VIDEO_ASPECT_RATIO', '16:9'),
        'credits' => (int) env('AI_VIDEO_CREDITS', 150),
        'max_minutes' => (int) env('AI_VIDEO_MAX_MINUTES', 20),
    ],
];
