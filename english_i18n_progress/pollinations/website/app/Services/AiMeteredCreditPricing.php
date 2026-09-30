<?php

namespace App\Services;

use InvalidArgumentException;

/** Internal Credit tariff, based on Gemini's measured usageMetadata (not character counts). */
final class AiMeteredCreditPricing
{
    public function quote(string $profile, array $usage): array
    {
        $prompt = max(0, (int) ($usage['promptTokenCount'] ?? 0));
        $cached = min($prompt, max(0, (int) ($usage['cachedContentTokenCount'] ?? 0)));
        $candidates = max(0, (int) ($usage['candidatesTokenCount'] ?? 0));
        $thoughts = max(0, (int) ($usage['thoughtsTokenCount'] ?? 0));
        $total = max(0, (int) ($usage['totalTokenCount'] ?? 0));

        if ($prompt === 0 && $candidates === 0 && $thoughts === 0 && $total === 0) {
            throw new InvalidArgumentException('Gemini did not return usable token consumption.');
        }

        // Normally total = prompt + candidate + thoughts (+ possible tool tokens).
        // Tool token usage is accounted for as output-like usage without double counting.
        $extra = max(0, $total - $prompt - $candidates - $thoughts);
        $multiplier = max(1.0, (float) config("ai_metered.profile_multipliers.{$profile}", 1.0))
            * $this->modelMultiplier((string) ($usage['model'] ?? ''));
        $inputCredits = (($prompt - $cached) / 1000) * max(0, (float) config('ai_metered.input_per_1k', 0.35));
        $cachedCredits = ($cached / 1000) * max(0, (float) config('ai_metered.cached_input_per_1k', 0.10));
        $outputCredits = (($candidates + $extra) / 1000) * max(0, (float) config('ai_metered.output_per_1k', 1.20));
        $thinkingCredits = ($thoughts / 1000) * max(0, (float) config('ai_metered.thinking_per_1k', 1.20));
        $raw = ($inputCredits + $cachedCredits + $outputCredits + $thinkingCredits) * $multiplier;

        return [
            'credits' => max((int) config('ai_metered.minimum_credits', 1), (int) ceil($raw - 0.0000001)),
            'raw_credits' => round($raw, 6),
            'profile' => $profile,
            'multiplier' => $multiplier,
            'input_tokens' => $prompt,
            'cached_input_tokens' => $cached,
            'output_tokens' => $candidates,
            'thinking_tokens' => $thoughts,
            'extra_tokens' => $extra,
            'total_tokens' => $total,
            'rates' => [
                'input_per_1k' => (float) config('ai_metered.input_per_1k', 0.35),
                'cached_input_per_1k' => (float) config('ai_metered.cached_input_per_1k', 0.10),
                'output_per_1k' => (float) config('ai_metered.output_per_1k', 1.20),
                'thinking_per_1k' => (float) config('ai_metered.thinking_per_1k', 1.20),
            ],
        ];
    }

    /** The stronger (pro) model costs more per token at Google, so its tokens weigh more in Credits. */
    private function modelMultiplier(string $model): float
    {
        $pro = trim((string) config('ai_assistant.pro_model', ''));
        $pollinationsPro = trim((string) config('pollinations.text_pro_model', ''));

        return ($pro !== '' && $model === $pro) || ($pollinationsPro !== '' && $model === 'pollinations:' . $pollinationsPro)
            ? max(1.0, (float) config('ai_assistant.pro_model_credit_multiplier', 4))
            : 1.0;
    }

    public function reserveEstimate(string $profile, int $textBytes, int $maxOutputTokens, int $mediaBytes = 0, ?string $model = null): int
    {
        // This is an estimate, not the final bill. Multimedia counts depend on model/modality.
        $promptTokens = max(1, $textBytes) + max(0, (int) config('ai_metered.context_reservation_tokens', 6000));
        $mediaTokens = (int) ceil(max(0, $mediaBytes) / 32);
        $maxOutputRate = max(0, (float) config('ai_metered.output_per_1k', 1.20));
        $maxThinkingRate = max(0, (float) config('ai_metered.thinking_per_1k', 1.20));
        $reservedOutput = max(1, $maxOutputTokens);
        $synthetic = [
            'promptTokenCount' => $promptTokens + $mediaTokens,
            // Gemini's maxOutputTokens cap includes thinking; reserve using the
            // more expensive output/thinking bucket, not both at once.
            'candidatesTokenCount' => $maxOutputRate >= $maxThinkingRate ? $reservedOutput : 0,
            'thoughtsTokenCount' => $maxOutputRate < $maxThinkingRate ? $reservedOutput : 0,
            'totalTokenCount' => $promptTokens + $mediaTokens + $reservedOutput,
            'model' => (string) $model,
        ];
        $quote = $this->quote($profile, $synthetic);
        return max(1, (int) ceil($quote['credits'] * max(1.0, (float) config('ai_metered.estimation_safety_factor', 1.4))));
    }
}
