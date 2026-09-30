<?php

namespace App\Services\AiAgent;

use App\Models\SupportMessage;
use App\Models\SupportTicket;
use App\Services\GeminiSupportService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

/**
 * Long conversations without forgetting:
 * - the most recent messages go to the model word for word (up to a character budget);
 * - everything older lives in a running summary stored on the conversation;
 * - a conversation that becomes extremely long continues in a new one that carries the summary.
 */
class ConversationMemoryService
{
    public function __construct(private readonly GeminiSupportService $gemini) {}

    /**
     * History for the prompt: [memory summary] + recent messages, oldest first.
     *
     * @return array<int,array{sender_type:string,message:string}>
     */
    public function history(SupportTicket $ticket, ?int $upToId = null): array
    {
        $budget = max(8000, (int) config('ai_assistant.context_chars', 120000));
        $maxMessages = max(12, (int) config('ai_assistant.context_messages', 120));

        $recent = [];
        $used = 0;
        $messages = $ticket->messages()
            ->where('is_internal', false)
            ->when($upToId, fn ($q) => $q->where('id', '<=', $upToId))
            ->orderByDesc('id')
            ->limit($maxMessages)
            ->get(['id', 'sender_type', 'message', 'attachment_name']);

        foreach ($messages as $message) {
            $text = trim((string) $message->message);
            if ($message->attachment_name) {
                $text .= "\n[ملف: " . $message->attachment_name . ']';
            }
            if ($text === '') {
                continue;
            }
            // Keep at least the last few turns whole; after that stop at the budget.
            if ($used + mb_strlen($text) > $budget && count($recent) >= 6) {
                break;
            }
            $used += mb_strlen($text);
            array_unshift($recent, ['sender_type' => (string) $message->sender_type, 'message' => $text]);
        }

        $summary = $this->hasMemoryColumns() ? trim((string) $ticket->ai_memory_summary) : '';

        return $summary !== ''
            ? array_merge([['sender_type' => 'memory', 'message' => $summary]], $recent)
            : $recent;
    }

    /**
     * Folds messages that fell out of the context window into the running summary.
     * Cheap when there is nothing new to fold (one COUNT-like query).
     */
    public function maybeSummarize(SupportTicket $ticket): void
    {
        if (! $this->hasMemoryColumns()) {
            return;
        }

        $windowIds = $ticket->messages()
            ->where('is_internal', false)
            ->orderByDesc('id')
            ->limit(max(12, (int) config('ai_assistant.context_messages', 120)))
            ->pluck('id');
        if ($windowIds->count() < 12) {
            return;
        }
        $windowStart = (int) $windowIds->min();
        $alreadyUpTo = (int) ($ticket->ai_memory_upto_id ?? 0);

        $outside = $ticket->messages()
            ->where('is_internal', false)
            ->where('id', '>', $alreadyUpTo)
            ->where('id', '<', $windowStart)
            ->orderBy('id')
            ->get(['id', 'sender_type', 'message', 'attachment_name']);

        $chars = $outside->sum(fn ($m) => mb_strlen((string) $m->message));
        if ($outside->isEmpty() || $chars < (int) config('ai_assistant.summary_trigger_chars', 12000)) {
            return;
        }

        $summary = $this->summarize((string) $ticket->ai_memory_summary, $outside->all());
        if ($summary !== null) {
            $ticket->forceFill([
                'ai_memory_summary' => $summary,
                'ai_memory_upto_id' => (int) $outside->last()->id,
            ])->save();
        }
    }

    public function shouldRollover(SupportTicket $ticket): bool
    {
        $count = $ticket->messages()->where('is_internal', false)->count();
        if ($count >= (int) config('ai_assistant.rollover_messages', 400)) {
            return true;
        }

        $chars = (int) $ticket->messages()->where('is_internal', false)->sum(DB::raw('LENGTH(message)'));

        return $chars >= (int) config('ai_assistant.rollover_chars', 800000);
    }

    /**
     * Continues a very long conversation in a new one: full summary + the last turns carried over.
     */
    public function rollover(SupportTicket $ticket): SupportTicket
    {
        // Summarise everything the model will no longer see word for word.
        $all = $ticket->messages()->where('is_internal', false)->orderBy('id')->get(['id', 'sender_type', 'message', 'attachment_name']);
        $keep = $all->slice(-6)->values();
        $older = $all->slice(0, max(0, $all->count() - 6))
            ->filter(fn ($m) => (int) $m->id > (int) ($this->hasMemoryColumns() ? ($ticket->ai_memory_upto_id ?? 0) : 0));
        $summary = $this->hasMemoryColumns() ? (string) $ticket->ai_memory_summary : '';
        if ($older->isNotEmpty()) {
            $summary = $this->summarize($summary, $older->all()) ?? $summary;
        }

        return DB::transaction(function () use ($ticket, $keep, $summary): SupportTicket {
            $title = Str::limit((string) ($ticket->assistant_title ?: $ticket->subject ?: 'محادثة AI'), 60, '') . ' (متابعة)';
            $fork = SupportTicket::create(array_filter([
                'ticket_number' => 'SUP-' . now()->format('Ymd') . '-' . strtoupper(Str::random(6)),
                'user_id' => $ticket->user_id,
                'assigned_employee_id' => null,
                'subject' => $title,
                'assistant_title' => $title,
                'is_ai_conversation' => true,
                'category' => $ticket->category ?: 'technical',
                'priority' => $ticket->priority ?: 'medium',
                'status' => 'open',
                'support_mode' => 'bot',
                'bot_resolved' => false,
                'last_message_at' => now(),
                'project_id' => $ticket->project_id,
                'ai_library_id' => $ticket->ai_library_id,
            ], fn ($v) => $v !== null));

            if ($this->hasMemoryColumns()) {
                // Not in the model's $fillable, so set directly.
                $fork->forceFill([
                    'ai_memory_summary' => $summary !== '' ? $summary : null,
                    'continued_from_ticket_id' => $ticket->id,
                ])->save();
            }

            SupportMessage::create([
                'support_ticket_id' => $fork->id,
                'sender_id' => null,
                'sender_type' => 'system',
                'message' => 'هذه متابعة للمحادثة ' . $ticket->ticket_number . ' لأنها صارت طويلة جدًا. المساعد يحمل ملخصًا كاملًا لما سبق، فأكمل من حيث توقفت.',
                'message_type' => 'text',
                'is_internal' => false,
            ]);
            foreach ($keep as $old) {
                SupportMessage::create([
                    'support_ticket_id' => $fork->id,
                    'sender_id' => $old->sender_type === 'customer' ? $ticket->user_id : null,
                    'sender_type' => $old->sender_type,
                    'message' => (string) $old->message,
                    'message_type' => 'text',
                    'is_internal' => false,
                ]);
            }

            return $fork;
        });
    }

    /** @param array<int,SupportMessage> $messages */
    private function summarize(string $previous, array $messages): ?string
    {
        $transcript = collect($messages)->map(function ($m): string {
            $who = match ($m->sender_type) { 'customer' => 'المستخدم', 'bot' => 'المساعد', default => 'النظام' };
            $text = mb_substr(trim((string) $m->message), 0, 6000);

            return $who . ': ' . $text . ($m->attachment_name ? ' [ملف: ' . $m->attachment_name . ']' : '');
        })->implode("\n\n");

        $prompt = "أنت مسؤول ذاكرة محادثة طويلة. حدّث الملخص التراكمي بحيث يستطيع مساعد آخر إكمال العمل دون أن يفقد أي شيء مهم.\n"
            . "احتفظ حرفيًا بكل: القرارات، المتطلبات، الأرقام والمقاسات، أسماء الملفات والمسارات، مقتطفات الكود المهمة وأسماء الدوال،\n"
            . "المشاكل المفتوحة، ما تم إنجازه، وما يريده المستخدم تاليًا. احذف المجاملات والتكرار. نظّمه بعناوين قصيرة.\n"
            . "لا تتجاوز 2500 كلمة. اكتب بالعربية مع ترك المصطلحات التقنية والكود كما هي.\n\n"
            . "الملخص الحالي:\n" . ($previous !== '' ? $previous : '(لا يوجد بعد)')
            . "\n\nالرسائل الجديدة التي يجب دمجها:\n" . $transcript;

        try {
            $summary = $this->gemini->generate($prompt, ['max_tokens' => 6000, 'temperature' => 0.1, 'thinking' => 'off']);
        } catch (Throwable $e) {
            Log::notice('Conversation summary failed.', ['error' => $e->getMessage()]);
            $summary = null;
        }

        return is_string($summary) && trim($summary) !== '' ? trim($summary) : null;
    }

    private function hasMemoryColumns(): bool
    {
        static $has = null;
        if ($has === null) {
            try {
                $has = Schema::hasColumn('support_tickets', 'ai_memory_summary')
                    && Schema::hasColumn('support_tickets', 'ai_memory_upto_id');
            } catch (Throwable) {
                $has = false;
            }
        }

        return $has;
    }
}
