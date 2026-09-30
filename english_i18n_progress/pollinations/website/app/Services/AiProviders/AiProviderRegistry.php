<?php

namespace App\Services\AiProviders;

use App\Contracts\AiProviderInterface;
use App\Services\AiAgent\ImageGenerationManager;
use App\Services\GeminiSupportService;

/**
 * Picks providers per service type from config, and tells the UI which generation modes really work.
 */
class AiProviderRegistry
{
    public function __construct(
        private readonly GeminiProvider $gemini,
        private readonly PollinationsProvider $pollinations,
        private readonly ImageGenerationManager $images,
        private readonly GeminiSupportService $text,
    ) {}

    public function provider(string $name): ?AiProviderInterface
    {
        return match ($name) {
            'gemini', 'veo' => $this->gemini,
            'pollinations' => $this->pollinations,
            default => null,
        };
    }

    /**
     * Configured AI providers able to serve this service, in the configured order.
     * service: text | image | image_edit | video
     *
     * @return array<int,AiProviderInterface>
     */
    public function forService(string $service): array
    {
        $order = match ($service) {
            'text' => (array) config('ai_assistant.text_providers', ['gemini', 'pollinations']),
            'video' => (array) config('ai_media.video.providers', []),
            default => (array) config('ai_media.image_providers', ['gemini']),
        };

        $providers = [];
        foreach ($order as $name) {
            $provider = $this->provider((string) $name);
            if ($provider && $provider->supports($service) && ! in_array($provider, $providers, true)) {
                $providers[] = $provider;
            }
        }

        return $providers;
    }

    /**
     * What the generation-mode buttons may offer. Computed on the server from real configuration
     * (and, for Pollinations, from its live model catalogue). No keys, providers or model names leave here.
     *
     * @return array{image:bool,edit_image:bool,video:bool}
     */
    public function mediaCapabilities(): array
    {
        return [
            'image' => $this->images->providers(false) !== [],
            'edit_image' => $this->images->providers(true) !== [],
            'video' => $this->text->videoAvailable(),
        ];
    }
}
