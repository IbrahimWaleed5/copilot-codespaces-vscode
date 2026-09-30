<?php

namespace App\Services\AiProviders;

use App\Contracts\AiProviderInterface;
use App\Services\GeminiSupportService;

class GeminiProvider implements AiProviderInterface
{
    public function __construct(private readonly GeminiSupportService $gemini) {}

    public function name(): string
    {
        return 'gemini';
    }

    public function isConfigured(): bool
    {
        return trim((string) config('services.gemini.api_key')) !== '';
    }

    public function supports(string $capability): bool
    {
        if (! $this->isConfigured()) {
            return false;
        }

        return match ($capability) {
            'text', 'image', 'image_edit' => true,
            'video' => (bool) config('ai_media.video.enabled', false) && in_array('veo', (array) config('ai_media.video.providers', []), true),
            default => false,
        };
    }

    public function generateText(string $prompt, array $options = [], ?array &$usage = null): ?string
    {
        return $this->gemini->generate($prompt, ['providers' => ['gemini']] + $options, $usage);
    }
}
