<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SupportAttachmentScan;
use App\Models\SupportInboundMessage;
use App\Models\SupportMessage;
use App\Models\SupportSetting;
use App\Models\SupportStaffProfile;
use App\Models\SupportTicket;
use App\Models\User;
use App\Services\PlatformPermissionService;
use App\Services\SupportAssignmentService;
use App\Services\SupportInboundService;
use App\Services\WhatsAppSupportService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

/**
 * أدوات الدعم الثلاث في التطبيق والموقع:
 *  - التوزيع التلقائي للتذاكر (SupportAssignmentService الموجود)
 *  - قنوات Email + WhatsApp الواردة (SupportInboundService / WhatsAppSupportService الموجودين)
 *  - فحص المرفقات (نفس إعدادات AttachmentSecurityService / ClamAV)
 * لا يغيّر أي منطق موجود؛ يعرضه ويديره فقط، مع نفس نظام الصلاحيات.
 */
class SupportToolsApiController extends Controller
{
    private const DEPARTMENTS = ['general', 'financial', 'kyc', 'technical'];
    private const OPEN_STATUSES = ['open', 'in_progress', 'waiting_customer'];

    public function __construct(private readonly PlatformPermissionService $permissions)
    {
    }

    private function allow(Request $request, string $permission): User
    {
        $user = $request->user();
        abort_unless($user && ($user->role === 'admin' || $this->permissions->allows($user, $permission)), 403);

        return $user;
    }

    // ------------------------------------------------------------------ التوزيع التلقائي

    public function assignment(Request $request)
    {
        $this->allow($request, 'support.tickets.assign');

        $profiles = Schema::hasTable('support_staff_profiles')
            ? SupportStaffProfile::query()->with('user:id,name,email,role,status')->orderBy('department')->orderBy('id')->get()
            : collect();

        $openCounts = SupportTicket::query()
            ->whereNotNull('assigned_employee_id')
            ->whereIn('status', self::OPEN_STATUSES)
            ->selectRaw('assigned_employee_id, COUNT(*) c')
            ->groupBy('assigned_employee_id')
            ->pluck('c', 'assigned_employee_id');

        $staff = $profiles
            ->filter(fn ($p) => $p->user && $p->user->role === 'employee')
            ->map(fn ($p) => [
                'id' => $p->id,
                'user_id' => $p->user_id,
                'name' => $p->user->name,
                'email' => $p->user->email,
                'user_status' => $p->user->status,
                'department' => $p->department ?: 'general',
                'level' => $p->level,
                'is_active' => (bool) $p->is_active,
                'auto_assign_enabled' => (bool) $p->auto_assign_enabled,
                'max_open_tickets' => max(1, (int) $p->max_open_tickets),
                'open_tickets' => (int) ($openCounts[$p->user_id] ?? 0),
                'last_assigned_at' => optional($p->last_assigned_at)->toIso8601String(),
            ])
            ->values();

        $fallback = SupportSetting::query()->with('supportEmployee:id,name,email')->first()?->supportEmployee;

        return response()->json([
            'departments' => self::DEPARTMENTS,
            'staff' => $staff,
            'waiting_count' => $this->waitingQuery()->count(),
            'eligible_count' => $staff->where('is_active', true)->where('auto_assign_enabled', true)->where('user_status', 'active')->count(),
            'fallback_employee' => $fallback ? ['id' => $fallback->id, 'name' => $fallback->name, 'email' => $fallback->email] : null,
        ]);
    }

    public function updateStaff(Request $request, SupportStaffProfile $profile)
    {
        $this->allow($request, 'support.tickets.assign');
        $data = $request->validate([
            'auto_assign_enabled' => ['sometimes', 'boolean'],
            'is_active' => ['sometimes', 'boolean'],
            'department' => ['sometimes', 'in:' . implode(',', self::DEPARTMENTS)],
            'max_open_tickets' => ['sometimes', 'integer', 'min:1', 'max:500'],
        ]);
        $profile->update($data);

        return response()->json(['message' => 'تم حفظ إعدادات الموظف.', 'profile' => $profile->fresh()]);
    }

    public function runAssignment(Request $request, SupportAssignmentService $service)
    {
        $this->allow($request, 'support.tickets.assign');

        $assigned = 0;
        $tickets = $this->waitingQuery()->orderBy('created_at')->limit(50)->get();
        foreach ($tickets as $ticket) {
            if ($service->assignEmployee($ticket)) {
                $assigned++;
            }
        }

        return response()->json([
            'message' => $assigned > 0 ? "تم توزيع {$assigned} تذكرة." : 'لا توجد تذاكر يمكن توزيعها الآن.',
            'assigned' => $assigned,
            'waiting_count' => $this->waitingQuery()->count(),
        ]);
    }

    private function waitingQuery()
    {
        return SupportTicket::query()
            ->whereNull('assigned_employee_id')
            ->whereIn('status', ['open', 'in_progress'])
            ->where(function ($q) {
                $q->where('support_mode', 'waiting_employee')->orWhere('is_ai_conversation', false)->orWhereNull('is_ai_conversation');
            })
            ->where(function ($q) {
                $q->whereNull('is_spam')->orWhere('is_spam', false);
            });
    }

    // ------------------------------------------------------------------ Email + WhatsApp

    public function channels(Request $request, WhatsAppSupportService $whatsapp)
    {
        $this->allow($request, 'support.channels.manage');

        $since = now()->subDays(30);
        $hasTable = Schema::hasTable('support_inbound_messages');
        $stats = $hasTable
            ? SupportInboundMessage::query()->where('created_at', '>=', $since)
                ->selectRaw('channel, status, COUNT(*) c')->groupBy('channel', 'status')->get()
                ->groupBy('channel')->map(fn ($rows) => $rows->pluck('c', 'status'))
            : collect();

        $recent = $hasTable
            ? SupportInboundMessage::query()->latest('id')->limit(40)->get()->map(fn ($m) => [
                'id' => $m->id,
                'channel' => $m->channel,
                'provider' => $m->provider,
                'from' => $this->mask((string) $m->from_address),
                'subject' => $m->subject,
                'excerpt' => mb_substr((string) $m->body, 0, 140),
                'status' => $m->status,
                'error' => $m->error_message,
                'ticket_number' => $m->support_ticket_id ? SupportTicket::query()->whereKey($m->support_ticket_id)->value('ticket_number') : null,
                'support_ticket_id' => $m->support_ticket_id,
                'created_at' => optional($m->created_at)->toIso8601String(),
            ])
            : collect();

        return response()->json([
            'email' => [
                'configured' => filled(config('support_v25.inbound_secret')),
                'webhook_url' => url('/api/webhooks/support/inbound-email'),
                'header' => 'X-Support-Webhook-Secret',
                'last_30_days' => $stats->get('email', collect()),
            ],
            'whatsapp' => [
                'sending_enabled' => $whatsapp->enabled(),
                'webhook_configured' => filled(config('support_v25.whatsapp.app_secret')) && filled(config('support_v25.whatsapp.verify_token')),
                'webhook_url' => url('/api/webhooks/whatsapp'),
                'graph_version' => (string) config('support_v25.whatsapp.graph_version', 'v23.0'),
                'last_30_days' => $stats->get('whatsapp', collect()),
            ],
            'recent' => $recent,
        ]);
    }

    public function retryInbound(Request $request, SupportInboundMessage $inbound, SupportInboundService $service)
    {
        $this->allow($request, 'support.channels.manage');
        abort_if($inbound->support_ticket_id, 422, 'هذه الرسالة مرتبطة بتذكرة بالفعل.');

        $ticket = $service->ingest((string) $inbound->channel, (array) ($inbound->payload ?? []));
        $inbound->update(['status' => 'reprocessed', 'support_ticket_id' => $ticket->id, 'processed_at' => now()]);

        return response()->json(['message' => 'تمت إعادة المعالجة وإنشاء/ربط التذكرة.', 'ticket_number' => $ticket->ticket_number]);
    }

    private function mask(string $value): string
    {
        if ($value === '') {
            return '';
        }
        if (str_contains($value, '@')) {
            [$name, $domain] = explode('@', $value, 2);

            return mb_substr($name, 0, 2) . '***@' . $domain;
        }

        return strlen($value) > 4 ? str_repeat('•', max(0, strlen($value) - 4)) . substr($value, -4) : $value;
    }

    // ------------------------------------------------------------------ فحص المرفقات

    public function attachments(Request $request)
    {
        $this->allow($request, 'support.files.view');
        $status = (string) $request->query('status', '');

        $base = SupportMessage::query()->whereNotNull('attachment_path');
        $stats = (clone $base)->selectRaw("COALESCE(scan_status, 'unknown') s, COUNT(*) c")->groupBy('s')->pluck('c', 's');

        $items = (clone $base)
            ->when($status !== '', fn ($q) => $status === 'unknown' ? $q->whereNull('scan_status') : $q->where('scan_status', $status))
            ->with('ticket:id,ticket_number,subject')
            ->latest('id')->limit(60)->get()
            ->map(function ($m) {
                $scan = Schema::hasTable('support_attachment_scans')
                    ? SupportAttachmentScan::query()->where('support_message_id', $m->id)->latest('id')->first()
                    : null;

                return [
                    'id' => $m->id,
                    'ticket_number' => $m->ticket?->ticket_number,
                    'support_ticket_id' => $m->support_ticket_id,
                    'name' => $m->attachment_name,
                    'mime' => $m->attachment_mime,
                    'size' => (int) $m->attachment_size,
                    'scan_status' => $m->scan_status ?: 'unknown',
                    'signature' => $scan?->signature,
                    'details' => $scan?->details,
                    'scanned_at' => optional($scan?->scanned_at)->toIso8601String(),
                    'created_at' => optional($m->created_at)->toIso8601String(),
                ];
            });

        $scanner = app(\App\Services\Security\ClamAvScanner::class);

        return response()->json([
            'scanner' => [
                'binary' => app(\App\Services\AttachmentSecurityService::class)->scannerLabel(),
                'mode' => $scanner->mode(),
                'available' => $scanner->available(),
                'version' => $scanner->version(),
                'strict' => (bool) config('clamav.strict') || (bool) config('support_v25.clamav_strict'),
                'max_mb' => max(1, (int) config('support_v25.attachment_max_mb', 10)),
                'allowed' => ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'zip', 'txt', 'csv'],
            ],
            'stats' => $stats,
            'items' => $items,
        ]);
    }

    public function rescan(Request $request, SupportMessage $message)
    {
        $this->allow($request, 'support.files.view');
        abort_unless(filled($message->attachment_path) && Storage::disk('local')->exists($message->attachment_path), 404, 'الملف غير موجود على الخادم.');

        $path = Storage::disk('local')->path($message->attachment_path);
        $scan = app(\App\Services\Security\ClamAvScanner::class)->scanPath($path);
        $status = $scan['status'];
        $signature = $scan['signature'];
        $details = $scan['details'];
        $binary = app(\App\Services\AttachmentSecurityService::class)->scannerLabel();
        if ($status === 'infected') {
            // An already stored file turned out to be infected: alert the admins too.
            app(\App\Services\Security\MalwareAlertService::class)->report([
                'file_name' => (string) $message->attachment_name,
                'file_size' => (int) $message->attachment_size,
                'sha256' => hash_file('sha256', $path) ?: null,
                'signature' => $signature,
                'engine' => $scan['engine'],
                'user_id' => $message->sender_id,
                'ip' => null,
                'route' => 'rescan support message #' . $message->id,
                'context' => ['source' => 'support_rescan', 'ticket_id' => $message->support_ticket_id, 'by' => $request->user()?->id],
            ]);
        }

        if (Schema::hasTable('support_attachment_scans')) {
            SupportAttachmentScan::create([
                'support_message_id' => $message->id,
                'path' => $message->attachment_path,
                'scanner' => $binary,
                'status' => $status,
                'signature' => $signature,
                'details' => $details,
                'scanned_at' => now(),
            ]);
        }
        $message->forceFill(['scan_status' => $status])->save();

        $text = match ($status) {
            'clean' => 'الملف سليم.',
            'infected' => 'تم اكتشاف ملف غير آمن.',
            'not_available' => 'فاحص المرفقات غير متاح على الخادم.',
            default => 'تعذر فحص المرفق أمنيًا. حاول لاحقًا.',
        };

        return response()->json(['message' => $text, 'scan_status' => $status]);
    }

    private function binaryExists(string $bin): bool
    {
        if ($bin === '') {
            return false;
        }
        if (str_contains($bin, '/') || str_contains($bin, '\\')) {
            return is_file($bin);
        }
        $cmd = PHP_OS_FAMILY === 'Windows' ? 'where ' . escapeshellarg($bin) : 'command -v ' . escapeshellarg($bin);
        @exec($cmd, $out, $code);

        return $code === 0;
    }
}
