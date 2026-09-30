<?php

namespace App\Services\AiAgent;

use App\Exceptions\AiCreditsExhaustedException;
use App\Models\Project;
use App\Models\SupportMessage;
use App\Models\SupportTicket;
use App\Services\AiCreditService;
use App\Services\AssistantSettingsService;
use App\Services\GeminiSupportService;
use App\Services\PlatformAiContextService;
use App\Services\ProjectFileAccessService;
use App\Services\ProjectFileVersionService;
use App\Services\SupportBotService;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

class AiAgentService
{
    public function __construct(
        private readonly AiCreditService $credits,
        private readonly AssistantSettingsService $settings,
        private readonly GeminiSupportService $gemini,
        private readonly GeminiImageGenerationService $images,
        private readonly AiArtifactBuilder $artifacts,
        private readonly AiCodeArtifactBuilder $codeArtifacts,
        private readonly SupportBotService $bot,
        private readonly PlatformAiContextService $context,
        private readonly ProjectFileAccessService $projectAccess,
        private readonly ProjectFileVersionService $projectFiles,
        private readonly ProjectAgentContextService $projectContext,
        private readonly AiAgentActionService $actions,
        private readonly ImageGenerationManager $imageManager,
        private readonly VideoGenerationService $videos,
    ) {}

    /** @return array{tool:string,save_to_project:bool}|null */
    public function detect(string $message, ?string $attachmentMime = null, ?string $attachmentName = null): ?array
    {
        $m = Str::lower(trim($message));
        $save = (bool) preg_match('/(?:احفظ|حفظ|ضيف|أضف|اضف).{0,18}(?:المشروع|ملفات\s*المشروع)|(?:save).{0,18}(?:project)/ui', $m);
        $isImageAttachment = is_string($attachmentMime) && str_starts_with(strtolower($attachmentMime), 'image/');
        $attachmentNameLower = strtolower((string) $attachmentName);
        $attachmentExtension = strtolower(pathinfo($attachmentNameLower, PATHINFO_EXTENSION));
        $isZipAttachment = str_contains(strtolower((string) $attachmentMime), 'zip') || $attachmentExtension === 'zip';
        $sourceExtensions = [
            'php','dart','js','mjs','cjs','ts','jsx','tsx','vue','svelte','py','java','kt','kts',
            'swift','go','rs','rb','cs','c','h','cpp','hpp','html','htm','css','scss','sass','less',
            'sql','graphql','gql','json','jsonc','yaml','yml','xml','toml','ini','properties','gradle',
            'md','txt','sh','bash','zsh','ps1','bat','cmd','conf','config',
        ];
        $isSourceAttachment = in_array($attachmentExtension, $sourceExtensions, true)
            || str_ends_with($attachmentNameLower, '.blade.php');

        if ($isImageAttachment && preg_match('/(?:عدل|عدّل|تعديل|غير|غيّر|احذف|أزل|ازل|ضيف|أضف|بدل|حوّل|حول|edit|modify|remove|replace|restyle)/ui', $m)) {
            return ['tool' => 'edit_image', 'save_to_project' => $save];
        }

        $asksCreate = (bool) preg_match('/(?:اعمل|اعملي|تعمل|أنشئ|انشئ|تنشئ|جهز|جهّز|تجهز|ولد|ولّد|تولد|صمم|صمّم|سوي|سوّي|اصنع|اخرج|أخرج|استخرج|صدّر|صدر|تصدر|create|generate|make|export|prepare)/ui', $m);
        $asksModify = (bool) preg_match('/(?:اصلح|أصلح|صلح|عدّل|عدل|تعديل|حدّث|حدث|طور|طوّر|refactor|fix|patch|update|modify|rewrite)/ui', $m);
        $asksOutput = $asksCreate
            || (bool) preg_match('/(?:حوّل|حول|بصيغة|كملف|نسخة\s+(?:من|بصيغة)|save\s+as|export\s+as)/ui', $m)
            || (bool) preg_match('/(?:بدي|أريد|اريد|أحتاج|احتاج)\s+(?:(?:ملف|تقرير|مستند|محضر|جدول)\s*.{0,30})?(?:word|docx|وورد|pdf|بي\s*دي\s*اف|excel|xlsx|اكسل|إكسل)/ui', $m);

        // أدوات البرمجة وحزم الاستبدال تسبق مستندات PDF/Word حتى لا تلتقط كلمة "ملف" فقط.
        $codeSignal = (bool) preg_match('/(?:برمج|برمجي|كود|code|source|flutter|dart|laravel|php|blade|javascript|typescript|node|react|vue|python|java|html|css|sql|api|controller|service|widget|screen|route|migration|config|pubspec|composer|package\.json)/ui', $m);
        $replacementSignal = (bool) preg_match('/(?:ملف|ملفات)\s*(?:استبدال|بديلة)|استبدال|replacement|replace\s+files?|patch\s+files?/ui', $m);
        $zipSignal = (bool) preg_match('/(?:\bzip\b|ملف\s*مضغوط|حزمة\s*(?:استبدال|برمجية)|package|bundle)/ui', $m);
        $multipleFilesSignal = (bool) preg_match('/(?:ملفات|files|عدة\s+ملفات|كل\s+الملفات)/ui', $m);
        $singleSourceFileSignal = (bool) preg_match('/(?:\.dart|\.php|\.blade\.php|\.js|\.ts|\.tsx|\.jsx|\.py|\.java|\.html|\.css|\.sql|\.json|\.ya?ml)\b/ui', $m);

        if (($asksCreate || $asksModify || $replacementSignal) && ($codeSignal || $replacementSignal || $isSourceAttachment || $isZipAttachment || $singleSourceFileSignal)) {
            $tool = ($replacementSignal || $zipSignal || $multipleFilesSignal || $isZipAttachment)
                ? 'code_zip'
                : 'code_file';
            return ['tool' => $tool, 'save_to_project' => $save];
        }

        // V6 secure action whitelist. These two intents create a REVIEWABLE DRAFT only.
        // The database is touched later only after an explicit Confirm button and a fresh hash check.
        $meetingTasksSignal = (bool) preg_match('/(?:محضر\s*(?:اجتماع|جلسة)|اجتماع|meeting\s+minutes|minutes\s+of\s+meeting|mom\b)/ui', $m)
            && (bool) preg_match('/(?:مهام|مهمات|tasks?|action\s*items?)/ui', $m)
            && (bool) preg_match('/(?:حوّل|حول|استخرج|أنشئ|انشئ|اعمل|جهز|create|convert|extract)/ui', $m);
        if ($meetingTasksSignal) {
            return ['tool' => 'meeting_tasks_action', 'save_to_project' => false];
        }

        $boqSignal = (bool) preg_match('/(?:\bboq\b|bill\s+of\s+quantities|جدول\s*(?:ال)?كميات|حصر\s*(?:ال)?كميات|حصر\s*كمي)/ui', $m);
        $boqApprovalSignal = $boqSignal && (bool) preg_match('/(?:اعتمد|اعتمده|اعتماد|ثبّت|ثبت|داخل\s+المشروع|في\s+المشروع|approve|commit)/ui', $m);
        if (($asksCreate || $asksOutput || $boqApprovalSignal) && $boqApprovalSignal) {
            return ['tool' => 'boq_approval_action', 'save_to_project' => false];
        }

        // أدوات Agent الهندسية/الإدارية المتخصصة. توضع قبل مولدات Word/PDF العامة
        // حتى يحصل المستخدم على سياق المشروع والأداة المناسبة بدل مستند عام فقط.
        if (($asksCreate || $asksOutput) && $boqSignal) {
            return ['tool' => 'boq', 'save_to_project' => $save];
        }

        $proposalSignal = (bool) preg_match('/(?:عرض\s*(?:سعر|أسعار|اسعار|فني|مالي)|quotation|commercial\s+proposal|technical\s+proposal|price\s+proposal)/ui', $m);
        if (($asksCreate || $asksOutput) && $proposalSignal) {
            return ['tool' => 'proposal', 'save_to_project' => $save];
        }

        $meetingMinutesSignal = (bool) preg_match('/(?:محضر\s*(?:اجتماع|جلسة)|meeting\s+minutes|minutes\s+of\s+meeting|mom\b)/ui', $m);
        if (($asksCreate || $asksOutput) && $meetingMinutesSignal) {
            return ['tool' => 'meeting_minutes', 'save_to_project' => $save];
        }

        $projectReportSignal = (bool) preg_match('/(?:تقرير\s*(?:المشروع|مشروع|حالة\s*المشروع|تقدم\s*المشروع)|project\s+(?:status\s+)?report|progress\s+report)/ui', $m);
        if (($asksCreate || $asksOutput) && $projectReportSignal) {
            return ['tool' => 'project_report', 'save_to_project' => $save];
        }

        $planSignal = (bool) preg_match('/(?:مخطط|مخططات|مسقط|لوحة\s+هندسية|drawing|drawings|floor\s*plan|architectural\s+plan|structural\s+plan)/ui', $m);
        $analysisSignal = (bool) preg_match('/(?:حلل|حلّل|تحليل|راجع|مراجعة|دقق|دقّق|افحص|فحص|استخرج|analy[sz]e|review|inspect|check)/ui', $m);
        if ($planSignal && $analysisSignal) {
            return ['tool' => 'plan_analysis', 'save_to_project' => $save];
        }

        // V6.3 routing rule: an explicit requested file format wins over ambiguous design words.
        // Example: "دراسة جدوى ... تصميم داخلي وخارجي ... اعمل ملف Word" must create DOCX,
        // not accidentally trigger image generation just because it contains "تصميم داخلي".
        $word = (bool) preg_match('/(?:word|docx|وورد|ورد\s+ملف|ملف\s+ورد|ملف\s+وورد)/ui', $m);
        $pdf = (bool) preg_match('/(?:pdf|بي\s*دي\s*اف|بدي\s*اف)/ui', $m);
        $excel = (bool) preg_match('/(?:excel|xlsx|اكسل|إكسل|جدول\s+بيانات)/ui', $m);
        $explicitDocumentOutput = $asksOutput && ($word || $pdf || $excel);

        if ($explicitDocumentOutput && $word && $pdf) return ['tool' => 'bundle', 'save_to_project' => $save];
        if ($explicitDocumentOutput && $excel) return ['tool' => 'xlsx', 'save_to_project' => $save];
        if ($explicitDocumentOutput && $word) return ['tool' => 'docx', 'save_to_project' => $save];
        if ($explicitDocumentOutput && $pdf) return ['tool' => 'pdf', 'save_to_project' => $save];

        // Image generation now needs an explicit visual-output signal.
        // Generic topics such as "تصميم داخلي" or "واجهة" alone are document/content topics,
        // unless the user explicitly asks for an image/render/visual output.
        $asksImage = (bool) preg_match('/(?:صورة|صور|رندر|render|visual|image|photo)/ui', $m);
        $strongImageRequest = (bool) preg_match('/(?:ولد|ولّد|تولد|أنشئ|انشئ|اعمل|اعملي|جهز|جهّز|صمم|صمّم|اصنع|اخرج|أخرج|generate|create|make|render).{0,28}(?:صورة|صور|رندر|render|visual|image|photo)/ui', $m)
            || (bool) preg_match('/(?:صورة|صور|رندر|render|visual|image|photo).{0,28}(?:ولد|ولّد|أنشئ|انشئ|اعمل|جهز|صمم|صمّم|generate|create|make)/ui', $m);
        if ($asksCreate && $asksImage && $strongImageRequest) return ['tool' => 'image', 'save_to_project' => $save];

        if ($asksCreate && preg_match('/(?:ملف|تقرير|مستند|document|report|محضر)/ui', $m)) {
            return ['tool' => 'pdf', 'save_to_project' => $save];
        }

        return null;
    }

    /**
     * Picks the tool for the current message.
     * First choice: the AI router, which reads the conversation and rewrites short follow-ups into a
     * complete request. Fallback: the keyword rules in detect() (router off, unreachable or unsure).
     *
     * @param array{path:string,name?:string,mime_type?:string}|null $attachment
     * @return array{tool:string,save_to_project:bool,request?:string,source?:string}|null
     */
    public function route(SupportTicket $ticket, string $message, ?array $attachment = null): ?array
    {
        $keyword = $this->detect($message, $attachment['mime_type'] ?? null, $attachment['name'] ?? null);

        if (! (bool) config('services.gemini.ai_router', true)) {
            return $keyword;
        }

        // Long plain questions that mention no output at all go straight to chat (no extra AI call).
        // Short messages always go through the router: they are usually follow-ups like "pdf" or "كمان وحدة".
        $mightWantOutput = (bool) preg_match('/(?:صور|صورة|رندر|ارسم|رسم|صمم|صمّم|تصميم|شكل|منظور|فيديو|مقطع|انيميشن|video|animation|word|docx|وورد|pdf|بي\s*دي\s*اف|excel|xlsx|اكسل|إكسل|ملف|file|zip|كود|code|جدول|تقرير|محضر|عرض\s*سعر|boq|كميات|اعمل|سوي|ولد|ولّد|انشئ|أنشئ|جهز|جهّز|حول|حوّل|render|image|draw|design|make|create|generate|convert|export)/ui', Str::lower($message));
        if (! $keyword && ! $mightWantOutput && ! $attachment && mb_strlen(trim($message)) > 60) {
            return null;
        }

        $conversation = $ticket->messages()
            ->where('is_internal', false)
            ->whereIn('sender_type', ['customer', 'bot'])
            ->orderByDesc('id')
            ->limit(9)
            ->get(['id', 'sender_type', 'message', 'attachment_name'])
            ->reverse()
            ->map(fn (SupportMessage $m) => [
                'sender_type' => $m->sender_type,
                'message' => (string) $m->message,
                'attachment_name' => $m->attachment_name,
            ])
            ->values()
            ->all();
        // The current message is usually already stored; drop it so it is not read twice.
        $last = end($conversation);
        if (is_array($last) && ($last['sender_type'] ?? '') === 'customer' && trim((string) $last['message']) === trim($message)) {
            array_pop($conversation);
        }

        $routed = $this->gemini->routeIntent($message, $conversation, $attachment['name'] ?? null, $attachment['mime_type'] ?? null);
        if (! $routed || $routed['confidence'] < 0.45) {
            return $keyword;
        }

        $intent = $routed['intent'];
        $save = $routed['save_to_project'] || (bool) ($keyword['save_to_project'] ?? false);
        $isImageAttachment = str_starts_with(strtolower((string) ($attachment['mime_type'] ?? '')), 'image/');

        // Guard rails: tools that need an attachment, and the two actions that write to a project,
        // only run when the request really supports them.
        if ($intent === 'edit_image' && ! $isImageAttachment) {
            $intent = 'image';
        }
        if ($intent === 'plan_analysis' && ! $attachment) {
            $intent = 'chat';
        }
        if (in_array($intent, ['meeting_tasks_action', 'boq_approval_action'], true) && ($keyword['tool'] ?? null) !== $intent) {
            $intent = $keyword['tool'] ?? 'chat';
        }

        if ($intent === 'chat' || $intent === null) {
            return null;
        }

        return [
            'tool' => $intent,
            'save_to_project' => $save,
            'request' => $routed['resolved_request'],
            'source' => 'ai_router',
        ];
    }

    /**
     * @param array{path:string,name?:string,mime_type?:string}|null $attachment
     * @param array{tool:string,save_to_project:bool,request?:string}|false|null $intent  null = decide now, false = no tool
     * @return array<string,mixed>
     */
    public function execute(
        Request $request,
        SupportTicket $ticket,
        string $message,
        string $assistantProfile = 'smart',
        string $assistantMode = 'work',
        array $pageContext = [],
        ?array $attachment = null,
        array|false|null $intent = null,
    ): array {
        if ($intent === null) {
            $intent = $this->route($ticket, $message, $attachment);
        }
        if (! $intent) return ['handled' => false];

        $tool = $intent['tool'];
        // The router's self-contained version of the request ("pdf" -> "make the previous house design as PDF").
        $originalMessage = $message;
        $message = trim((string) ($intent['request'] ?? '')) !== '' ? (string) $intent['request'] : $message;

        if ($tool === 'video' && ! $this->videos->enabled()) {
            return $this->videoUnavailable($ticket, $originalMessage);
        }
        $wallet = $this->credits->walletForRequest($request);
        try {
            $this->assertToolAvailable($request, $tool, $wallet);
        } catch (RuntimeException $e) {
            if ($tool === 'video') {
                return [
                    'handled' => true,
                    'error_status' => 403,
                    'error' => 'توليد الفيديو يحتاج باقة AI Pro مع تفعيل الأدوات الهندسية.',
                    'code' => 'ai_agent_video_requires_pro',
                    'required_plan' => 'AI Pro',
                    'entitlement' => $this->credits->payload($wallet),
                ];
            }
            $isImageTool = in_array($tool, ['image', 'edit_image'], true);
            $isCodeTool = in_array($tool, ['code_file', 'code_zip'], true);
            $isPlanTool = $tool === 'plan_analysis';
            $isBoqTool = in_array($tool, ['boq', 'boq_approval_action'], true);
            return [
                'handled' => true,
                'error_status' => 403,
                'error' => $isImageTool
                    ? 'توليد وتعديل الصور يحتاج باقة AI Pro مع تفعيل الأدوات الهندسية.'
                    : ($isPlanTool
                        ? 'تحليل المخططات يحتاج AI Pro مع تفعيل تحليل الملفات والأدوات الهندسية ومهارة مراجعة المخططات.'
                        : ($isCodeTool
                            ? 'إنشاء الملفات البرمجية وحزم ZIP يحتاج باقة AI Plus أو أعلى مع تفعيل Code ومهارة البرمجة.'
                            : ($isBoqTool
                                ? 'BOQ Generator يحتاج AI Plus مع تفعيل مساعد التقارير ومهارة تحليل الكميات.'
                                : 'هذه الأداة تحتاج AI Plus مع تفعيل مساعد التقارير.'))),
                'code' => $isImageTool
                    ? 'ai_agent_image_requires_pro'
                    : ($isPlanTool
                        ? 'ai_agent_plan_analysis_requires_pro'
                        : ($isCodeTool ? 'ai_agent_code_requires_plus' : 'ai_agent_document_requires_plus')),
                'required_plan' => ($isImageTool || $isPlanTool) ? 'AI Pro' : 'AI Plus',
                'entitlement' => $this->credits->payload($wallet),
            ];
        }

        if ($tool === 'video') {
            return $this->startVideo($request, $ticket, $message);
        }

        // V6: only two business-write actions exist. This step creates a draft preview only;
        // confirm/edit/cancel are handled separately through the same /support-bot/send endpoint.
        if (in_array($tool, ['meeting_tasks_action', 'boq_approval_action'], true)) {
            $cost = $this->toolCredits($tool);
            try {
                $usage = $this->credits->reserve(
                    $request,
                    operation: 'agent_' . $tool,
                    credits: $cost,
                    supportTicketId: $ticket->id,
                    metadata: [
                        'channel' => 'smart_assistant_agent',
                        'tool' => $tool,
                        'fixed_tool_cost' => $cost,
                        'execution_mode' => 'preview_only',
                    ]
                );
            } catch (AiCreditsExhaustedException $e) {
                return [
                    'handled' => true,
                    'error_status' => 402,
                    'error' => $e->getMessage(),
                    'code' => 'ai_credits_exhausted',
                    'entitlement' => $e->entitlement,
                ];
            }

            try {
                $result = $this->actions->createPreview(
                    $request,
                    $ticket,
                    $tool,
                    $message,
                    $pageContext,
                    $attachment
                );
                $usage = $this->credits->complete(
                    $usage,
                    $result['provider'] ?? 'gemini+secure-action-preview',
                    $result['model'] ?? (string) config('services.gemini.model'),
                    strlen($message),
                    (int) ($result['output_chars'] ?? 0)
                );
                $result['credits_charged'] = (int) $usage->credits_used;
                $result['entitlement'] = $this->credits->payload($this->credits->walletForRequest($request));
                return $result;
            } catch (Throwable $e) {
                try { $this->credits->refund($usage, 'secure_action_preview_failed'); } catch (Throwable) {}
                Log::warning('Secure AI action preview failed.', [
                    'tool' => $tool,
                    'ticket_id' => $ticket->id,
                    'error' => $e->getMessage(),
                ]);
                $permissionError = preg_match('/(?:صلاحية|لا تملك|متاح فقط|غير مصرح)/u', $e->getMessage()) === 1;
                return [
                    'handled' => true,
                    'error_status' => $permissionError ? 403 : 422,
                    'error' => $e->getMessage(),
                    'code' => $permissionError ? 'ai_agent_action_forbidden' : 'ai_agent_action_preview_invalid',
                    'entitlement' => $this->credits->payload($this->credits->walletForRequest($request)),
                ];
            }
        }

        $advancedTools = ['boq', 'proposal', 'meeting_minutes', 'project_report', 'plan_analysis'];
        $project = null;
        if (in_array($tool, $advancedTools, true)) {
            $project = $this->projectContext->resolve($request->user(), $ticket, $pageContext, $message, $tool);
            if ($tool === 'project_report' && ! $project) {
                return [
                    'handled' => true,
                    'error_status' => 422,
                    'error' => 'لإنشاء تقرير مشروع من بيانات المنصة، افتح المساعد من داخل المشروع أو اذكر رقم المشروع الذي تملك صلاحية الوصول إليه.',
                    'code' => 'ai_agent_project_required',
                    'entitlement' => $this->credits->payload($wallet),
                ];
            }
            if ($tool === 'plan_analysis' && ! $attachment) {
                return [
                    'handled' => true,
                    'error_status' => 422,
                    'error' => 'أرفق المخطط كصورة أو PDF ثم اكتب ما تريد مراجعته، وسأرجع لك تقرير تحليل فعلي.',
                    'code' => 'ai_agent_plan_attachment_required',
                    'entitlement' => $this->credits->payload($wallet),
                ];
            }
        }

        $cost = $this->toolCredits($tool);
        try {
            $usage = $this->credits->reserve(
                $request,
                operation: 'agent_' . $tool,
                credits: $cost,
                supportTicketId: $ticket->id,
                metadata: [
                    'channel' => 'smart_assistant_agent',
                    'tool' => $tool,
                    'fixed_tool_cost' => $cost,
                    'project_id' => $project?->id ?? $ticket->project_id,
                ]
            );
        } catch (AiCreditsExhaustedException $e) {
            return [
                'handled' => true,
                'error_status' => 402,
                'error' => $e->getMessage(),
                'code' => 'ai_credits_exhausted',
                'required_plan' => null,
                'entitlement' => $e->entitlement,
            ];
        }

        try {
            $title = $this->titleFor($message, $tool);
            if (in_array($tool, ['image', 'edit_image'], true)) {
                $artifact = $this->imageManager->generate(
                    $this->imagePrompt($ticket, $message),
                    (int) $request->user()->id,
                    (int) $ticket->id,
                    $tool === 'edit_image' ? $attachment : null
                );
                $summary = $tool === 'edit_image'
                    ? 'تم تعديل الصورة وتجهيز النسخة الجديدة.'
                    : 'تم توليد الصورة وتجهيزها لك.';
                $provider = ($artifact['provider'] ?? 'gemini') === 'gemini' ? 'gemini-image' : 'image-' . $artifact['provider'];
                $model = $artifact['model'] ?? config('services.gemini.image_model');
                $outputChars = 0;
            } elseif (in_array($tool, ['code_file', 'code_zip'], true)) {
                $package = $this->generateCodePackage(
                    $request,
                    $ticket,
                    $message,
                    $assistantProfile,
                    $assistantMode,
                    $pageContext,
                    $attachment,
                    $tool
                );
                $artifact = $this->codeArtifacts->build(
                    $tool,
                    $title,
                    $package['files'],
                    (int) $request->user()->id,
                    (int) $ticket->id
                );
                $count = (int) ($artifact['file_count'] ?? count($package['files']));
                $summary = $tool === 'code_zip' || $count > 1
                    ? 'تم تجهيز حزمة ZIP استبدال برمجية تحتوي على ' . $count . ' ملف/ملفات مع الحفاظ على المسارات.'
                    : 'تم إنشاء الملف البرمجي المطلوب وجاهز للفتح أو الاستبدال.';
                if (trim((string) ($package['summary'] ?? '')) !== '') {
                    $summary .= ' ' . Str::limit(trim((string) $package['summary']), 280, '…');
                }
                $provider = 'gemini+code-artifact-builder';
                $model = (string) config('services.gemini.model');
                $outputChars = (int) ($package['output_chars'] ?? 0);
            } elseif (in_array($tool, $advancedTools, true)) {
                $content = $this->generateAdvancedContent(
                    $request,
                    $ticket,
                    $message,
                    $pageContext,
                    $attachment,
                    $tool,
                    $project
                );
                if (! is_string($content) || trim($content) === '') {
                    throw new RuntimeException('تعذر إنشاء محتوى الأداة المتخصصة.');
                }
                $artifactTool = $this->advancedArtifactTool($tool, $message);
                $artifact = $this->artifacts->build(
                    $artifactTool,
                    $title,
                    $content,
                    (int) $request->user()->id,
                    (int) $ticket->id
                );
                $summary = match ($tool) {
                    'boq' => 'تم تجهيز BOQ احترافي قابل للتنزيل.',
                    'proposal' => 'تم تجهيز العرض الفني/المالي المطلوب.',
                    'meeting_minutes' => 'تم إنشاء محضر الاجتماع بصورة منظمة.',
                    'project_report' => 'تم إنشاء تقرير المشروع من البيانات المصرح بها في المنصة.',
                    'plan_analysis' => 'تم تحليل المخطط المرفق وتجهيز تقرير المراجعة.',
                    default => 'تم تنفيذ أداة المشروع.',
                };
                $provider = 'gemini+project-agent';
                $model = (string) config('services.gemini.model');
                $outputChars = strlen($content);
            } else {
                $content = $this->generateDocumentContent($request, $ticket, $message, $assistantProfile, $assistantMode, $pageContext, $tool);
                if (! is_string($content) || trim($content) === '') throw new RuntimeException('تعذر إنشاء محتوى المستند.');
                $artifact = $this->artifacts->build($tool, $title, $content, (int) $request->user()->id, (int) $ticket->id);
                $summary = match ($tool) {
                    'docx' => 'تم إنشاء ملف Word احترافي وجاهز للفتح.',
                    'pdf' => 'تم إنشاء ملف PDF احترافي وجاهز للفتح.',
                    'xlsx' => 'تم إنشاء ملف Excel وجاهز للفتح.',
                    'bundle' => 'تم إنشاء Word + PDF وتجميعهما في ملف ZIP واحد.',
                    default => 'تم إنشاء الملف المطلوب.',
                };
                $provider = 'gemini+document-builder';
                $model = (string) config('services.gemini.model');
                $outputChars = strlen($content);
            }

            $projectFile = null;
            $projectSaveNote = '';
            $explicitNoProjectSave = (bool) preg_match('/(?:بدون|لا)\s*(?:حفظ|تحفظ|تخزن|تخزين).{0,18}(?:المشروع|ملفات\s*المشروع)/ui', Str::lower($message));
            $autoProjectTool = in_array($tool, $advancedTools, true);
            $shouldSaveToProject = ! $explicitNoProjectSave
                && (($intent['save_to_project'] ?? false) || ($autoProjectTool && $project));

            if ($shouldSaveToProject && $project) {
                try {
                    $projectFile = $this->saveToProject($request, $ticket, $project, $artifact, $title);
                    $projectSaveNote = $projectFile ? ' وتم حفظ نسخة تلقائيًا داخل ملفات المشروع.' : '';
                } catch (Throwable $e) {
                    Log::notice('AI artifact project save skipped.', ['ticket_id' => $ticket->id, 'project_id' => $project->id, 'error' => $e->getMessage()]);
                    $projectSaveNote = ' تم إنشاء الملف، لكن لم يُحفظ داخل المشروع بسبب صلاحيات ملفات المشروع.';
                }
            } elseif (($intent['save_to_project'] ?? false) && ! $project) {
                $projectSaveNote = ' لربطه بالمشروع، افتح المحادثة من مساحة المشروع أو اذكر رقم المشروع الذي تملك صلاحية الوصول إليه.';
            }

            $botMessage = SupportMessage::create([
                'support_ticket_id' => $ticket->id,
                'sender_id' => null,
                'sender_type' => 'bot',
                'message' => $summary . $projectSaveNote,
                'message_type' => in_array($tool, ['image', 'edit_image'], true) ? 'image' : 'file',
                'is_internal' => false,
                'attachment_path' => $artifact['path'],
                'attachment_name' => $artifact['name'],
                'attachment_mime' => $artifact['mime'],
                'attachment_size' => (int) $artifact['size'],
                'scan_status' => 'generated',
            ]);

            $ticket->forceFill(['last_message_at' => now(), 'bot_confidence' => null])->save();
            $usage = $this->credits->complete($usage, $provider, $model ? (string) $model : null, strlen($message), $outputChars);

            return [
                'handled' => true,
                'tool' => $tool,
                'message' => $botMessage->load('sender:id,name'),
                'credits_charged' => (int) $usage->credits_used,
                'project_saved' => (bool) $projectFile,
                'project_file_id' => $projectFile?->id,
                'entitlement' => $this->credits->payload($this->credits->walletForRequest($request)),
            ];
        } catch (Throwable $e) {
            try { $this->credits->refund($usage, 'agent_tool_failed'); } catch (Throwable) {}
            Log::error('AI agent tool failed.', ['tool' => $tool, 'ticket_id' => $ticket->id, 'error' => $e->getMessage()]);
            return [
                'handled' => true,
                'error_status' => 503,
                'error' => 'تعذر تنفيذ أداة ' . $this->toolLabel($tool) . ' الآن، وتمت إعادة الرصيد المحجوز.',
                'code' => 'ai_agent_tool_failed',
                'entitlement' => $this->credits->payload($this->credits->walletForRequest($request)),
            ];
        }
    }

    /** Starts a video at the provider; it is posted into the chat later by the message polling. */
    private function startVideo(Request $request, SupportTicket $ticket, string $message): array
    {
        $cost = max(1, (int) config('ai_media.video.credits', 150));
        try {
            $usage = $this->credits->reserve($request, operation: 'agent_video', credits: $cost, supportTicketId: $ticket->id,
                metadata: ['channel' => 'smart_assistant_agent', 'tool' => 'video', 'fixed_tool_cost' => $cost]);
        } catch (AiCreditsExhaustedException $e) {
            return ['handled' => true, 'error_status' => 402, 'error' => $e->getMessage(), 'code' => 'ai_credits_exhausted', 'entitlement' => $e->entitlement];
        }

        try {
            $started = $this->videos->start($ticket, (int) $request->user()->id, $this->imagePrompt($ticket, $message), $usage);
        } catch (Throwable $e) {
            try { $this->credits->refund($usage, 'video_start_failed'); } catch (Throwable) {}
            Log::warning('AI video could not start.', ['ticket_id' => $ticket->id, 'error' => $e->getMessage()]);

            return [
                'handled' => true,
                'error_status' => 503,
                'error' => 'تعذر بدء إنشاء الفيديو: ' . $e->getMessage() . ' تمت إعادة الرصيد المحجوز.',
                'code' => 'ai_agent_tool_failed',
                'entitlement' => $this->credits->payload($this->credits->walletForRequest($request)),
            ];
        }

        $botMessage = SupportMessage::create([
            'support_ticket_id' => $ticket->id,
            'sender_id' => null,
            'sender_type' => 'bot',
            'message' => '🎬 بدأت أجهّز الفيديو (' . ($started['provider'] === 'veo' ? 'Veo' : 'ComfyUI') . '). '
                . 'عادة ياخد من دقيقة لـ 5 دقائق، ورح يظهر هنا تلقائيًا أول ما يجهز. خليك على هاي المحادثة.',
            'message_type' => 'text',
            'is_internal' => false,
        ]);
        $ticket->forceFill(['last_message_at' => now()])->save();

        return [
            'handled' => true,
            'tool' => 'video',
            'message' => $botMessage->load('sender:id,name'),
            'credits_charged' => 0, // settled when the video arrives, refunded if it fails
            'project_saved' => false,
            'project_file_id' => null,
            'entitlement' => $this->credits->payload($this->credits->walletForRequest($request)),
        ];
    }

    /** Video generation is not available on the platform: say so clearly instead of producing something else. */
    private function videoUnavailable(SupportTicket $ticket, string $message): array
    {
        $botMessage = SupportMessage::create([
            'support_ticket_id' => $ticket->id,
            'sender_id' => null,
            'sender_type' => 'bot',
            'message' => "توليد الفيديو غير متاح حاليًا داخل المنصة.\n\n"
                . "أقدر بدلًا منه:\n"
                . "• أولّد لك صور رندر للتصميم من عدة زوايا (اكتب: ولّد صور للتصميم من 4 زوايا).\n"
                . "• أجهز لك سيناريو مشاهد (Storyboard) للفيديو كملف PDF لتسلّمه لمصمم الفيديو.",
            'message_type' => 'text',
            'is_internal' => false,
        ]);
        $ticket->forceFill(['last_message_at' => now()])->save();

        return [
            'handled' => true,
            'tool' => 'video',
            'message' => $botMessage->load('sender:id,name'),
            'credits_charged' => 0,
            'project_saved' => false,
            'project_file_id' => null,
            'entitlement' => $this->credits->payload($this->credits->walletForRequest(request())),
        ];
    }

    private function assertToolAvailable(Request $request, string $tool, $wallet): void
    {
        if (in_array($tool, ['image', 'edit_image', 'video'], true)) {
            if (! $this->credits->featureEnabled($wallet, 'engineering_tools') || ! $this->settings->pluginEnabled($request->user(), 'engineering_tools')) {
                throw new RuntimeException('agent_requires_pro');
            }
            return;
        }

        if (in_array($tool, ['code_file', 'code_zip'], true)) {
            $setting = $this->settings->settingFor($request->user());
            $skills = array_map('strval', $setting->enabled_skills ?? []);
            if (! $this->credits->featureEnabled($wallet, 'report_assistant')
                || ! (bool) $setting->code_enabled
                || ! in_array('software_code', $skills, true)) {
                throw new RuntimeException('agent_code_requires_plus');
            }
            return;
        }

        $setting = $this->settings->settingFor($request->user());
        $skills = array_map('strval', $setting->enabled_skills ?? []);

        if ($tool === 'plan_analysis') {
            if (! $this->credits->featureEnabled($wallet, 'engineering_tools')
                || ! $this->settings->pluginEnabled($request->user(), 'engineering_tools')
                || ! $this->settings->pluginEnabled($request->user(), 'file_analysis')
                || ! in_array('drawing_review', $skills, true)) {
                throw new RuntimeException('agent_plan_analysis_requires_pro');
            }
            return;
        }

        if (in_array($tool, ['boq', 'boq_approval_action'], true)) {
            if (! $this->credits->featureEnabled($wallet, 'report_assistant')
                || ! $this->settings->pluginEnabled($request->user(), 'report_assistant')
                || ! in_array('boq_analysis', $skills, true)) {
                throw new RuntimeException('agent_boq_requires_plus');
            }
            return;
        }

        if ($tool === 'meeting_tasks_action') {
            if (! $this->credits->featureEnabled($wallet, 'report_assistant')
                || ! $this->settings->pluginEnabled($request->user(), 'report_assistant')) {
                throw new RuntimeException('agent_meeting_tasks_requires_plus');
            }
            return;
        }

        if (! $this->credits->featureEnabled($wallet, 'report_assistant') || ! $this->settings->pluginEnabled($request->user(), 'report_assistant')) {
            throw new RuntimeException('agent_requires_plus');
        }
    }

    private function imagePrompt(SupportTicket $ticket, string $message): string
    {
        $history = $ticket->messages()
            ->where('is_internal', false)
            ->orderByDesc('id')
            ->limit(6)
            ->get()
            ->reverse()
            ->map(function (SupportMessage $item): string {
                $role = $item->sender_type === 'customer' ? 'المستخدم' : ($item->sender_type === 'bot' ? 'المساعد' : 'السياق');
                $text = trim((string) $item->message);
                return $text === '' ? '' : $role . ': ' . Str::limit($text, 700, '');
            })
            ->filter()
            ->implode("\n");

        return trim(($history !== '' ? "سياق المحادثة ذي الصلة:\n{$history}\n\n" : '') . "طلب الصورة الحالي:\n{$message}");
    }

    private function generateDocumentContent(Request $request, SupportTicket $ticket, string $message, string $profile, string $mode, array $pageContext, string $tool): ?string
    {
        $conversation = $ticket->messages()
            ->where('is_internal', false)
            ->orderByDesc('id')->limit(14)->get()->reverse()
            ->map(fn (SupportMessage $m) => ['sender_type' => $m->sender_type, 'message' => $m->message])
            ->values()->all();
        $runtime = $this->context->build(
            $request->user(),
            $this->settings->browserContextEnabled($request->user()) ? $pageContext : [],
            ['connectors' => $this->settings->enabledConnectors($request->user())]
        );
        $runtime .= "\n" . $this->settings->runtimeContext($request->user());
        $formatInstruction = $tool === 'xlsx'
            ? 'أنشئ المحتوى كجدول Markdown واضح باستخدام | بين الأعمدة. اجعل الصف الأول عناوين الأعمدة ولا تضف شرحًا خارج الجدول إلا عند الضرورة.'
            : 'أنشئ محتوى مستند نهائي مهني بالعربية، بعناوين واضحة وفقرات وقوائم وجداول Markdown عند الحاجة. لا تقل إنك ستنشئ الملف؛ اكتب محتوى الملف نفسه.';

        return $this->gemini->answer(
            question: $message . "\n\nتعليمات أداة المستند: " . $formatInstruction,
            knowledgeContext: "هذه عملية Agent فعلية لإنشاء ملف. " . $this->bot->buildKnowledgeContext($message),
            conversation: $conversation,
            userContext: $this->bot->buildUserContext($request->user()),
            runtimeContext: $runtime,
            assistantMode: $mode === 'chat' ? 'work' : $mode,
            assistantProfile: in_array($profile, ['fast', 'smart'], true) ? 'smart' : $profile,
        );
    }

    /**
     * أدوات المشاريع المتخصصة: BOQ، العروض، محاضر الاجتماعات، تقارير المشروع، وتحليل المخططات.
     *
     * @param array{path:string,name?:string,mime_type?:string}|null $attachment
     */
    private function generateAdvancedContent(
        Request $request,
        SupportTicket $ticket,
        string $message,
        array $pageContext,
        ?array $attachment,
        string $tool,
        ?Project $project,
    ): ?string {
        $conversation = $ticket->messages()
            ->where('is_internal', false)
            ->orderByDesc('id')
            ->limit(18)
            ->get()
            ->reverse()
            ->map(fn (SupportMessage $m) => [
                'sender_type' => $m->sender_type,
                'message' => $m->message,
            ])
            ->values()
            ->all();

        $runtime = $this->context->build(
            $request->user(),
            $this->settings->browserContextEnabled($request->user()) ? $pageContext : [],
            ['connectors' => $this->settings->enabledConnectors($request->user())]
        );
        $runtime .= "\n" . $this->settings->runtimeContext($request->user());

        if ($project) {
            $runtime .= "\n\n" . $this->projectContext->build($request->user(), $project);
        }

        $instruction = match ($tool) {
            'boq' => <<<'PROMPT'
أنت BOQ Generator هندسي داخل منصة مشاريع. أنشئ جدول كميات فعليًا من المعلومات المصرح بها وطلب المستخدم.
أخرج جدول Markdown فقط قدر الإمكان حتى يُحوّله النظام إلى Excel. الأعمدة المفضلة:
| رقم البند | القسم | الوصف | الوحدة | الكمية | سعر الوحدة | الإجمالي | الملاحظات |
قواعد مهمة:
- إذا كانت كمية/سعر غير موجودين في البيانات أو الطلب فلا تخترع قيمة مؤكدة. استخدم "غير محدد" أو ضع افتراضًا واضحًا في الملاحظات.
- لا تعتبر تقديرًا تقريبيًا قياسًا نهائيًا. فرّق بوضوح بين البيانات الفعلية والافتراضات.
- إذا كان هناك مخطط/ملف مرفق، استخرج منه فقط ما يمكن قراءته بثقة واذكر أي نقص أو افتراض في الملاحظات.
- إذا كانت بيانات BOQ موجودة في سياق المشروع، استخدمها كأساس وحافظ على الوحدات والعملات.
- احسب الإجمالي فقط عندما تتوفر كمية وسعر وحدة صالحان.
- لا تكتب مقدمة طويلة خارج الجدول. يمكن إضافة سطر ملاحظات قصير بعد الجدول عند الضرورة.
PROMPT,
            'proposal' => <<<'PROMPT'
أنشئ عرضًا فنيًا/ماليًا احترافيًا جاهزًا كوثيقة رسمية. استخدم أي ملف متطلبات/نطاق مرفق إن وجد مع اعتباره مصدرًا إضافيًا لا يعلو على بيانات المشروع المصرح بها.
رتب المحتوى إلى: عنوان العرض، بيانات المشروع/العميل المتاحة، فهم نطاق العمل، نطاق الخدمات، المنهجية والمخرجات، البرنامج الزمني، السعر وشروط الدفعات عندما تكون موجودة، الافتراضات والاستثناءات، مدة صلاحية العرض، وخاتمة.
لا تخترع اسم عميل أو سعرًا أو مدة غير موجودة. إذا طلب المستخدم تقديرًا ولم يعطِ قيمة، استخدم بند "يحدد بعد المعاينة/الاتفاق" بدل رقم مختلق.
PROMPT,
            'meeting_minutes' => <<<'PROMPT'
أنشئ محضر اجتماع مهني جاهز للحفظ.
استخدم بيانات أحدث اجتماع ذي صلة في سياق المشروع إن وجدت، ثم سياق المحادثة، ثم أي مرفق مثل تسجيل/تفريغ/ملاحظات اجتماع إذا كان قابلاً للتحليل.
رتب المحضر إلى: بيانات الاجتماع، الحضور، جدول الأعمال، ملخص المناقشات، القرارات، الإجراءات المطلوبة (المهمة/المسؤول/الموعد/الحالة)، نقاط المتابعة، والملاحظات.
لا تخترع أسماء حضور أو قرارات أو مواعيد. أي معلومة غير متاحة اتركها "غير محدد" بدل اختلاقها.
PROMPT,
            'project_report' => <<<'PROMPT'
أنشئ تقرير حالة مشروع احترافي اعتمادًا على بيانات المشروع المصرح بها. إذا أرفق المستخدم تقريرًا أو ملفًا إضافيًا، استخدمه كمصدر إضافي وميّز ما جاء منه عن حقائق المنصة عند وجود تعارض.
يشمل عند توفر البيانات: الملخص التنفيذي، حالة المشروع، النطاق، الجدول والمراحل، نسبة التقدم، المهام المتأخرة/القادمة، الفريق، الاجتماعات والقرارات، BOQ/الكميات، الملفات والتسليمات، الحالة المالية والدفعات والمصروفات لمن لديه صلاحية مالية، المخاطر والملاحظات، ثم الإجراءات التالية.
ميّز بوضوح بين حقائق المنصة وبين الاستنتاجات. لا تخترع نسبة تقدم عامة إذا لم يمكن اشتقاقها؛ اذكر أن النسبة غير متاحة أو لخص تقدم المراحل الموجودة.
PROMPT,
            'plan_analysis' => <<<'PROMPT'
حلل المخطط/اللوحة المرفقة كمراجعة هندسية أولية واكتب تقريرًا منظمًا.
يشمل عند الإمكان: نوع المخطط ومحتواه، القراءة العامة، الملاحظات المعمارية/الإنشائية/التنسيقية الظاهرة، الأبعاد أو التسميات المقروءة، التعارضات أو النواقص المحتملة، نقاط تحتاج تحققًا، وقائمة توصيات مرتبة بالأولوية.
لا تدّعِ رؤية تفاصيل غير مقروءة. لا تخترع أبعادًا أو مناسيب أو قطاعات. أي استنتاج بصري غير مؤكد اذكره بصفته "ملاحظة تحتاج تحقق".
هذا التحليل مساعد للمراجعة ولا يستبدل اعتماد مهندس مختص أو مراجعة المخطط الأصلي عالي الدقة.
PROMPT,
            default => 'أنشئ مستندًا مهنيًا منظمًا من طلب المستخدم والبيانات المتاحة دون اختلاق حقائق.',
        };

        $profile = match ($tool) {
            'plan_analysis' => 'design3d',
            'boq', 'project_report' => 'engineering',
            default => 'smart',
        };

        return $this->gemini->answer(
            question: $message . "\n\nتعليمات الأداة:\n" . $instruction,
            knowledgeContext: "هذه عملية AI Agent فعلية داخل منصة الوليد الهندسية. أنشئ المحتوى النهائي للأداة ولا تقل إنك ستنشئه لاحقًا. " . $this->bot->buildKnowledgeContext($message),
            conversation: $conversation,
            userContext: $this->bot->buildUserContext($request->user()),
            runtimeContext: $runtime,
            attachment: $attachment,
            assistantMode: 'work',
            assistantProfile: $profile,
        );
    }

    private function advancedArtifactTool(string $tool, string $message): string
    {
        $m = Str::lower($message);
        $wantsWord = (bool) preg_match('/(?:word|docx|وورد|ملف\s*ورد)/ui', $m);
        $wantsPdf = (bool) preg_match('/(?:pdf|بي\s*دي\s*اف|بدي\s*اف)/ui', $m);
        $wantsExcel = (bool) preg_match('/(?:excel|xlsx|اكسل|إكسل)/ui', $m);

        if (in_array($tool, ['boq', 'boq_approval_action'], true)) {
            if ($wantsExcel && $wantsPdf) return 'boq_bundle';
            if ($wantsPdf && ! $wantsExcel) return 'pdf';
            if ($wantsWord && ! $wantsExcel) return 'docx';
            return 'xlsx';
        }

        if ($tool === 'plan_analysis') {
            if ($wantsWord && ! $wantsPdf) return 'docx';
            return 'pdf';
        }

        if ($wantsWord && $wantsPdf) return 'bundle';
        if ($wantsWord) return 'docx';
        if ($wantsPdf) return 'pdf';

        // الأدوات الإدارية الافتراضية ترجع Word + PDF داخل ZIP واحد.
        return 'bundle';
    }

    /**
     * @param array{path:string,name?:string,mime_type?:string}|null $attachment
     * @return array{files:array<int,array{path:string,content:string}>,summary:string,output_chars:int}
     */
    private function generateCodePackage(
        Request $request,
        SupportTicket $ticket,
        string $message,
        string $profile,
        string $mode,
        array $pageContext,
        ?array $attachment,
        string $tool,
    ): array {
        $conversation = $ticket->messages()
            ->where('is_internal', false)
            ->orderByDesc('id')->limit(14)->get()->reverse()
            ->map(fn (SupportMessage $m) => ['sender_type' => $m->sender_type, 'message' => $m->message])
            ->values()->all();

        $runtime = $this->context->build(
            $request->user(),
            $this->settings->browserContextEnabled($request->user()) ? $pageContext : [],
            ['connectors' => $this->settings->enabledConnectors($request->user())]
        );
        $runtime .= "\n" . $this->settings->runtimeContext($request->user());

        $packageMode = $tool === 'code_zip'
            ? 'المطلوب حزمة استبدال ZIP. أخرج فقط الملفات الجديدة أو المعدلة اللازمة، مع مسار كل ملف كما يجب أن يوضع داخل المشروع.'
            : 'المطلوب ملف برمجي واحد قدر الإمكان. إذا كانت صحة الحل تتطلب أكثر من ملف، أخرج الملفات اللازمة وسيتم تجميعها تلقائيًا في ZIP.';

        $protocol = <<<'PROMPT'
أنت الآن تبني ملفات برمجية فعلية ليحفظها النظام كمرفقات. لا تكتفِ بشرح الكود.
أعد النتيجة حصريًا بالبروتوكول النصي التالي، بدون Markdown fences حول البروتوكول وبدون نص قبله أو بعده:

<<<ALWALEED_FILE path="المسار/اسم_الملف.ext">>>
محتوى الملف كاملًا كما يجب أن يُحفظ، بدون اختصار وبدون نقاط حذف.
<<<ALWALEED_END_FILE>>>

كرر كتلة FILE لكل ملف مطلوب، ثم أخيرًا:
<<<ALWALEED_SUMMARY>>>
ملخص عربي قصير جدًا لما تم إنشاؤه أو إصلاحه وأي أمر اختبار مهم.
<<<ALWALEED_END_SUMMARY>>>

قواعد مهمة:
- الملفات يجب أن تكون كاملة وقابلة للاستبدال، وليست snippets إذا طلب المستخدم ملف استبدال.
- استخدم مسارات مشروع منطقية مثل lib/... أو app/... أو resources/views/... حسب التقنية والسياق.
- إذا كان هناك ملف مرفق أو ZIP مرفق، اعتبر محتواه مرجع المشروع الحالي، أصلح المطلوب وأخرج ملفات الاستبدال فقط.
- لا تنشئ .env أو مفاتيح API أو أسرار أو كلمات مرور. استخدم .env.example عند الحاجة.
- لا تدّعِ تشغيل الكود أو الاختبارات. يمكنك تضمين أمر الاختبار المقترح في SUMMARY فقط.
- لا تضع ``` داخل حدود FILE إلا إذا كانت جزءًا حرفيًا من محتوى الملف نفسه.
PROMPT;

        $answer = $this->gemini->answer(
            question: $message . "\n\n{$packageMode}\n\n{$protocol}",
            knowledgeContext: "هذه عملية AI Agent لإنشاء ملفات برمجية فعلية وحزمة استبدال، وليست إجابة كود عادية. " . $this->bot->buildKnowledgeContext($message),
            conversation: $conversation,
            userContext: $this->bot->buildUserContext($request->user()),
            runtimeContext: $runtime,
            attachment: $attachment,
            assistantMode: 'work',
            assistantProfile: 'programming',
        );

        if (! is_string($answer) || trim($answer) === '') {
            throw new RuntimeException('تعذر إنشاء محتوى الملفات البرمجية.');
        }

        $files = $this->parseCodeFiles($answer, $message);
        if ($files === []) {
            throw new RuntimeException('لم يرجع مزود AI ملفات برمجية بصيغة قابلة للحفظ.');
        }

        $summary = '';
        if (preg_match('/<<<ALWALEED_SUMMARY>>>\s*(.*?)\s*<<<ALWALEED_END_SUMMARY>>>/su', $answer, $match)) {
            $summary = trim((string) $match[1]);
        }

        return [
            'files' => $files,
            'summary' => $summary,
            'output_chars' => strlen($answer),
        ];
    }

    /** @return array<int,array{path:string,content:string}> */
    private function parseCodeFiles(string $answer, string $message): array
    {
        $files = [];
        if (preg_match_all('/<<<ALWALEED_FILE\s+path=(?:"([^"]+)"|\'([^\']+)\')>>>\s*\R?(.*?)\R?<<<ALWALEED_END_FILE>>>/su', $answer, $matches, PREG_SET_ORDER)) {
            foreach ($matches as $match) {
                $path = trim((string) (($match[1] ?? '') !== '' ? $match[1] : ($match[2] ?? '')));
                $content = (string) ($match[3] ?? '');
                $content = preg_replace('/\A```[^\r\n]*\R(.*)\R```\s*\z/su', '$1', $content) ?? $content;
                if ($path !== '' && trim($content) !== '') {
                    $files[] = ['path' => $path, 'content' => rtrim($content) . "\n"];
                }
            }
        }

        if ($files !== []) {
            return $files;
        }

        // Fallback لموديل لم يلتزم بالبروتوكول: نحفظ أول code fence كملف واحد بدل ضياع الناتج.
        if (preg_match('/```([a-zA-Z0-9_+.-]*)\s*\R(.*?)\R```/su', $answer, $match)) {
            $language = strtolower(trim((string) ($match[1] ?? '')));
            $extension = match ($language) {
                'dart' => 'dart', 'php' => 'php', 'javascript', 'js' => 'js', 'typescript', 'ts' => 'ts',
                'python', 'py' => 'py', 'java' => 'java', 'html' => 'html', 'css' => 'css', 'sql' => 'sql',
                'json' => 'json', 'yaml', 'yml' => 'yaml', default => 'txt',
            };
            $name = 'generated_code.' . $extension;
            if (preg_match('/([\pL\pN_\-./\\ ]+\.(?:dart|php|js|ts|tsx|jsx|py|java|html|css|sql|json|ya?ml))/ui', $message, $nameMatch)) {
                $name = trim(str_replace('\\', '/', (string) $nameMatch[1]));
            }
            return [['path' => $name, 'content' => rtrim((string) $match[2]) . "\n"]];
        }

        return [];
    }

    private function saveToProject(Request $request, SupportTicket $ticket, Project $project, array $artifact, string $title)
    {
        $access = $this->projectAccess->resolve($request->user(), $project);
        if (! $this->projectAccess->canUploadNewFile($access)) throw new RuntimeException('No project upload permission.');
        $uploaded = new UploadedFile(
            $artifact['absolute_path'],
            $artifact['name'],
            $artifact['mime'],
            null,
            true
        );
        return $this->projectFiles->createFile($project, $request->user(), [
            'title' => $title,
            'description' => 'ملف تم إنشاؤه بواسطة مساعد الوليد الهندسية داخل المحادثة #' . $ticket->id,
            'change_notes' => 'تم الإنشاء بواسطة AI Agent.',
        ], $uploaded);
    }

    private function toolCredits(string $tool): int
    {
        return match ($tool) {
            'image' => (int) config('services.gemini.agent_credits.image', 35),
            'edit_image' => (int) config('services.gemini.agent_credits.edit_image', 40),
            'docx' => (int) config('services.gemini.agent_credits.docx', 12),
            'pdf' => (int) config('services.gemini.agent_credits.pdf', 14),
            'xlsx' => (int) config('services.gemini.agent_credits.xlsx', 14),
            'bundle' => (int) config('services.gemini.agent_credits.bundle', 22),
            'code_file' => (int) config('services.gemini.agent_credits.code_file', 18),
            'code_zip' => (int) config('services.gemini.agent_credits.code_zip', 28),
            'boq' => (int) config('services.gemini.agent_credits.boq', 22),
            'boq_approval_action' => (int) config('services.gemini.agent_credits.boq_approval_preview', 22),
            'meeting_tasks_action' => (int) config('services.gemini.agent_credits.meeting_tasks_preview', 18),
            'proposal' => (int) config('services.gemini.agent_credits.proposal', 20),
            'meeting_minutes' => (int) config('services.gemini.agent_credits.meeting_minutes', 18),
            'project_report' => (int) config('services.gemini.agent_credits.project_report', 24),
            'plan_analysis' => (int) config('services.gemini.agent_credits.plan_analysis', 26),
            default => 10,
        };
    }

    private function titleFor(string $message, string $tool): string
    {
        $clean = preg_replace('/(?:pdf|word|docx|xlsx|excel|وورد|اكسل|إكسل|zip|ملف|ملفات|استبدال|اعمل|اعملي|أنشئ|انشئ|جهز|جهّز|ولد|ولّد|صمم|صمّم)/ui', ' ', $message) ?? $message;
        $clean = trim(preg_replace('/\s+/u', ' ', $clean) ?? $clean);
        if ($clean === '') $clean = match ($tool) {
            'image', 'edit_image' => 'تصميم بالذكاء الاصطناعي',
            'xlsx' => 'جدول بيانات',
            'code_file' => 'ملف برمجي',
            'code_zip' => 'حزمة استبدال برمجية',
            'boq' => 'جدول كميات BOQ',
            'proposal' => 'عرض فني ومالي',
            'meeting_minutes' => 'محضر اجتماع',
            'project_report' => 'تقرير المشروع',
            'plan_analysis' => 'تحليل مخطط',
            default => 'مستند هندسي',
        };
        return Str::limit($clean, 64, '');
    }

    private function toolLabel(string $tool): string
    {
        return match ($tool) {
            'image' => 'توليد الصور',
            'edit_image' => 'تعديل الصور',
            'docx' => 'Word',
            'pdf' => 'PDF',
            'xlsx' => 'Excel',
            'bundle' => 'Word + PDF',
            'code_file' => 'إنشاء ملف برمجي',
            'code_zip' => 'حزمة ZIP للاستبدال',
            'boq' => 'BOQ Generator',
            'boq_approval_action' => 'مسودة اعتماد BOQ الآمنة',
            'meeting_tasks_action' => 'تحويل محضر الاجتماع إلى مهام',
            'proposal' => 'مولد العروض الفنية والمالية',
            'meeting_minutes' => 'محاضر الاجتماعات',
            'project_report' => 'تقارير المشاريع',
            'plan_analysis' => 'تحليل المخططات',
            default => 'Agent',
        };
    }
}
