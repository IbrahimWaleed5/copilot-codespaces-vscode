<?php

namespace App\Contracts;

/**
 * An AI provider the platform can switch between per service type.
 * Capabilities: text | image | image_edit | video | image_to_video.
 * The order per service comes from config (AI_TEXT_PROVIDERS, AI_IMAGE_PROVIDERS, AI_VIDEO_PROVIDERS).
 */
interface AiProviderInterface
{
    /** Stable key used in config lists, e.g. "gemini", "pollinations". */
    public function name(): string;

    /** Has its credentials on the server. */
    public function isConfigured(): bool;

    /** Can do this job right now (checked programmatically, not assumed). */
    public function supports(string $capability): bool;

    /**
     * Plain text generation used by the agents pipeline.
     *
     * @param array{max_tokens?:int,temperature?:float,json_schema?:array,thinking?:string,model?:string} $options
     * @param array|null $usage  token usage in Gemini usageMetadata shape (for metered Credits)
     */
    public function generateText(string $prompt, array $options = [], ?array &$usage = null): ?string;
}
