<?php

namespace App\Services\AiProviders;

use App\Contracts\AiProviderInterface;
use App\Services\GeminiSupportService;
use App\Services\PollinationsService;

class PollinationsProvider implements AiProviderInterface
{
    public function __construct(
        private readonly PollinationsService $pollinations,
        private readonly GeminiSupportService $text,
    ) {}

    public function name(): string
    {
        return 'pollinations';
    }

    public function isConfigured(): bool
    {
        return $this->pollinations->configured();
    }

    public function supports(string $capability): bool
    {
        if (! $this->isConfigured()) {
            return false;
        }

        // Media capabilities are read from the live model catalogue of this key (cached).
        return match ($capability) {
            'text' => true,
            'image' => $this->pollinations->resolveModel('image') !== null,
            'image_edit' => $this->pollinations->resolveModel('edit') !== null,
            'video' => $this->pollinations->supportsVideo(),
            'image_to_video' => $this->pollinations->supportsVideo(true),
            default => false,
        };
    }

    public function generateText(string $prompt, array $options = [], ?array &$usage = null): ?string
    {
        return $this->text->generate($prompt, ['providers' => ['pollinations']] + $options, $usage);
    }
}
