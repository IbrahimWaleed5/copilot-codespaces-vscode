<?php

namespace App\Services\AiAgent;

use App\Services\GeminiSupportService;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Agents pipeline for complex requests (system analysis, architecture, substantial code, long reports):
 *   1. Planner  – breaks the task into a few concrete steps.
 *   2. Workers  – one focused pass per step, each seeing the results of the previous steps.
 *   3. Reviewer – checks everything for mistakes/gaps and writes the single final answer.
 * The plan and progress are returned as the visible "thinking".
 */
class AgentOrchestrator
{
    public function __construct(private readonly GeminiSupportService $gemini) {}

    public function enabledFor(string $profile): bool
    {
        return (bool) config('ai_assistant.agents_enabled', true)
            && in_array($profile, (array) config('ai_assistant.agents_profiles', []), true);
    }

    /**
     * @param array<int,array{sender_type:string,message:string}> $conversation
     * @return array{answer:string,thinking:string,usage:?array,steps:int}|null  null = fall back to a normal answer
     */
    public function run(
        string $question,
        string $knowledgeContext,
        array $conversation,
        string $userContext,
        string $runtimeContext,
        string $profile,
        string $mode,
    ): ?array {
        @set_time_limit(600);
        $usage = null;
        $defaultModel = (string) config('services.gemini.model', 'gemini-3.1-flash-lite');
        $model = $this->gemini->modelFor($defaultModel, $profile === 'fast' ? 'smart' : $profile, 'thinking');

        // ── 1. Planner ───────────────────────────────────────────────────
        $recent = collect($conversation)->take(-10)->map(fn ($m) => ($m['sender_type'] === 'customer' ? 'المستخدم' : ($m['sender_type'] === 'memory' ? 'ملخص سابق' : 'المساعد'))
            . ': ' . mb_substr((string) $m['message'], 0, 1500))->implode("\n");
        $maxSteps = max(2, min(8, (int) config('ai_assistant.agents_max_steps', 5)));
        $planPrompt = "أنت وكيل التخطيط (Planner) لفريق وكلاء ذكاء اصطناعي خبير في الهندسة والبرمجة وتحليل الأنظمة.\n"
            . "قسّم طلب المستخدم إلى خطوات عمل حقيقية ومتتابعة (من 2 إلى {$maxSteps}) ينجز كل منها وكيل مستقل.\n"
            . "كل خطوة يجب أن تنتج مخرجًا ملموسًا (تحليل، تصميم، كود، حسابات، مقارنة...). لا تضع خطوات عامة مثل \"فهم الطلب\".\n"
            . "آخر خطوة لا تكون \"كتابة الرد النهائي\" لأن هناك مراجعًا نهائيًا يتولاها.\n\n"
            . "سياق المحادثة الأخير:\n" . ($recent !== '' ? $recent : '(لا يوجد)') . "\n\nطلب المستخدم الحالي:\n" . $question;

        $planUsage = null;
        $planJson = $this->gemini->generate($planPrompt, [
            'model' => $model,
            'max_tokens' => 2000,
            'temperature' => 0.2,
            'thinking' => 'low',
            'json_schema' => [
                'type' => 'OBJECT',
                'properties' => [
                    'goal' => ['type' => 'STRING'],
                    'steps' => ['type' => 'ARRAY', 'items' => [
                        'type' => 'OBJECT',
                        'properties' => ['title' => ['type' => 'STRING'], 'instruction' => ['type' => 'STRING']],
                        'required' => ['title', 'instruction'],
                    ]],
                ],
                'required' => ['goal', 'steps'],
            ],
        ], $planUsage);
        $usage = GeminiSupportService::mergeUsage($usage, $planUsage);

        $plan = is_string($planJson) ? json_decode(preg_replace('/^```(?:json)?\s*|\s*```$/u', '', trim($planJson)) ?? $planJson, true) : null;
        $steps = array_values(array_filter((array) ($plan['steps'] ?? []), fn ($s) => is_array($s) && trim((string) ($s['instruction'] ?? '')) !== ''));
        if (count($steps) < 2) {
            return null; // simple after all: the normal single answer is better
        }
        $steps = array_slice($steps, 0, $maxSteps);
        $goal = trim((string) ($plan['goal'] ?? ''));

        $thinking = "🧭 الخطة" . ($goal !== '' ? ' — ' . $goal : '') . "\n";
        foreach ($steps as $i => $step) {
            $thinking .= ($i + 1) . '. ' . trim((string) $step['title']) . "\n";
        }

        // ── 2. Workers ───────────────────────────────────────────────────
        $results = [];
        foreach ($steps as $i => $step) {
            $previous = collect($results)->map(fn ($r, $k) => '### نتيجة الخطوة ' . ($k + 1) . ': ' . $r['title'] . "\n" . mb_substr($r['output'], 0, 9000))->implode("\n\n");
            $workerQuestion = "أنت الوكيل رقم " . ($i + 1) . ' من ' . count($steps) . " في فريق وكلاء. الهدف الكامل: " . ($goal !== '' ? $goal : $question) . "\n\n"
                . "طلب المستخدم الأصلي:\n{$question}\n\n"
                . ($previous !== '' ? "نتائج الوكلاء السابقين (ابنِ عليها ولا تكررها):\n{$previous}\n\n" : '')
                . "مهمتك الآن فقط: " . trim((string) $step['title']) . "\n" . trim((string) $step['instruction']) . "\n\n"
                . "أنجز مهمتك بعمق وبدقة مهنية كاملة. إن كانت برمجية فاكتب كودًا كاملًا صحيحًا قابلًا للتشغيل. لا تكتب مقدمة أو خاتمة.";

            $stepUsage = null;
            $stepThoughts = null;
            $output = $this->gemini->answer(
                question: $workerQuestion,
                knowledgeContext: $knowledgeContext,
                conversation: $conversation,
                userContext: $userContext,
                runtimeContext: $runtimeContext,
                assistantMode: 'work',
                usageMetrics: $stepUsage,
                assistantProfile: $profile,
                thoughtSummary: $stepThoughts,
            );
            $usage = GeminiSupportService::mergeUsage($usage, $stepUsage);

            if (! is_string($output) || trim($output) === '') {
                Log::notice('Agent step returned nothing.', ['step' => $i + 1]);
                $thinking .= "\n⚠️ الخطوة " . ($i + 1) . ' لم ترجع نتيجة، أكمل الفريق بدونها.';
                continue;
            }
            $results[] = ['title' => trim((string) $step['title']), 'output' => $output];
            $thinking .= "\n✅ الخطوة " . ($i + 1) . ': ' . trim((string) $step['title']);
            if (is_string($stepThoughts) && trim($stepThoughts) !== '') {
                $thinking .= "\n" . Str::limit(trim($stepThoughts), 700, '…');
            }
        }

        if ($results === []) {
            return null;
        }

        // ── 3. Reviewer / final answer ───────────────────────────────────
        $work = collect($results)->map(fn ($r, $k) => '### ' . ($k + 1) . '. ' . $r['title'] . "\n" . $r['output'])->implode("\n\n");
        $reviewQuestion = "أنت المراجع النهائي (Reviewer) لفريق وكلاء أنجز العمل التالي لطلب المستخدم.\n"
            . "1) دقّق النتائج: صحّح أي خطأ تقني أو حسابي أو برمجي، وأكمل أي نقص، واحذف التكرار والتعارض.\n"
            . "2) اكتب للمستخدم الإجابة النهائية الكاملة والمنظمة مباشرة، وكأنك كتبتها بنفسك. لا تذكر الوكلاء أو الخطوات الداخلية.\n"
            . "3) أي كود يجب أن يكون كاملًا ومتسقًا بين الأجزاء.\n\n"
            . "طلب المستخدم:\n{$question}\n\nعمل الفريق:\n{$work}";

        $reviewUsage = null;
        $reviewThoughts = null;
        $final = $this->gemini->answer(
            question: $reviewQuestion,
            knowledgeContext: $knowledgeContext,
            conversation: $conversation,
            userContext: $userContext,
            runtimeContext: $runtimeContext,
            assistantMode: 'work',
            usageMetrics: $reviewUsage,
            assistantProfile: $profile,
            thoughtSummary: $reviewThoughts,
        );
        $usage = GeminiSupportService::mergeUsage($usage, $reviewUsage);

        if (! is_string($final) || trim($final) === '') {
            // The reviewer failed: the workers' results are still useful as they are.
            $final = $work;
        }
        $thinking .= "\n\n🔎 مراجعة نهائية وتدقيق للنتائج";
        if (is_string($reviewThoughts) && trim($reviewThoughts) !== '') {
            $thinking .= "\n" . Str::limit(trim($reviewThoughts), 900, '…');
        }

        return ['answer' => trim($final), 'thinking' => mb_substr($thinking, 0, 6000), 'usage' => $usage, 'steps' => count($results)];
    }
}
