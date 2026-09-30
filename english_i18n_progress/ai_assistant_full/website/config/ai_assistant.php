<?php

/*
|--------------------------------------------------------------------------
| Smart assistant: models, long memory and agents
|--------------------------------------------------------------------------
*/

return [
    // Stronger model for programming / engineering / design / expert levels and deep thinking,
    // e.g. gemini-2.5-pro or gemini-3-pro-preview. Empty = use GEMINI_MODEL for everything.
    'pro_model' => env('GEMINI_PRO_MODEL', ''),
    'pro_profiles' => ['programming', 'engineering', 'design3d', 'expert'],
    'pro_for_thinking_mode' => (bool) env('GEMINI_PRO_FOR_THINKING', true),
    'pro_timeout' => (int) env('GEMINI_PRO_TIMEOUT', 180),

    // Longest answer (tokens). Long code files and full analyses need 16k+.
    'max_output_tokens' => (int) env('AI_MAX_OUTPUT_TOKENS', 16384),

    // ── Long conversations ──────────────────────────────────────────────
    // Recent messages are sent word for word up to this many characters (~4 chars per token);
    // everything older is kept as a running summary, so nothing is forgotten.
    'context_chars' => (int) env('AI_CONTEXT_CHARS', 120000),
    'context_messages' => (int) env('AI_CONTEXT_MESSAGES', 120),
    // Summarise the older part once this many characters are outside the window.
    'summary_trigger_chars' => (int) env('AI_SUMMARY_TRIGGER_CHARS', 12000),
    // A conversation this long continues automatically in a new one (with the full summary).
    'rollover_messages' => (int) env('AI_ROLLOVER_MESSAGES', 400),
    'rollover_chars' => (int) env('AI_ROLLOVER_CHARS', 800000),

    // ── Agents (planner → workers → reviewer) for complex tasks ───────
    'agents_enabled' => (bool) env('AI_AGENTS_ENABLED', true),
    // Levels that may use the agents pipeline (the router still has to mark the task complex).
    'agents_profiles' => ['smart', 'programming', 'engineering', 'design3d', 'expert'],
    'agents_max_steps' => (int) env('AI_AGENTS_MAX_STEPS', 5),
];
