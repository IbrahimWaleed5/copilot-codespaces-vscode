<?php
namespace App\Services;

use App\Models\SupportAttachmentScan;
use App\Models\SupportMessage;
use App\Services\Security\ClamAvScanner;
use App\Services\Security\MalwareAlertService;
use Illuminate\Http\UploadedFile;
use RuntimeException;

class AttachmentSecurityService
{
    public function __construct(
        private readonly ClamAvScanner $scanner,
        private readonly MalwareAlertService $alerts,
    ) {}

    public function scanUpload(UploadedFile $file): array
    {
        $max = max(1, (int) config('support_v25.attachment_max_mb', 10)) * 1024 * 1024;
        if ($file->getSize() > $max) throw new RuntimeException('حجم المرفق يتجاوز الحد المسموح.');
        $allowed = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'zip', 'txt', 'csv'];
        $ext = strtolower($file->getClientOriginalExtension());
        if (! in_array($ext, $allowed, true)) throw new RuntimeException('نوع الملف غير مسموح.');

        $result = $this->scanner->scanPath($file->getRealPath());
        $status = $result['status'];
        $signature = $result['signature'];
        $details = $result['details'];

        if ($status === 'infected') {
            $this->alerts->report([
                'file_name' => $file->getClientOriginalName(),
                'file_size' => (int) $file->getSize(),
                'sha256' => hash_file('sha256', $file->getRealPath()) ?: null,
                'signature' => $signature,
                'engine' => $result['engine'],
                'user_id' => request()->user()?->id,
                'ip' => request()->ip(),
                'route' => mb_substr(request()->method() . ' ' . request()->path(), 0, 190),
                'context' => ['source' => 'support_attachment'],
            ]);
            throw new RuntimeException('تم رفض المرفق لأن فحص الحماية اكتشف ملفًا غير آمن.');
        }
        if (in_array($status, ['error', 'not_available'], true) && $this->strict()) {
            throw new RuntimeException($status === 'error' ? 'تعذر فحص المرفق أمنيًا. حاول لاحقًا.' : 'فاحص المرفقات غير متاح على الخادم.');
        }

        return compact('status', 'details', 'signature');
    }

    public function record(?SupportMessage $message, string $path, array $scan): void
    {
        SupportAttachmentScan::create([
            'support_message_id' => $message?->id,
            'path' => $path,
            'scanner' => $this->scannerLabel(),
            'status' => $scan['status'] ?? 'unknown',
            'signature' => $scan['signature'] ?? null,
            'details' => $scan['details'] ?? null,
            'scanned_at' => now(),
        ]);
        if ($message) $message->forceFill(['scan_status' => $scan['status'] ?? 'unknown'])->save();
    }

    public function scannerLabel(): string
    {
        return match ($this->scanner->mode()) {
            'clamd' => 'clamd@' . config('clamav.host') . ':' . config('clamav.port', 3310),
            'binary' => (string) config('clamav.binary', 'clamscan'),
            default => 'none',
        };
    }

    private function strict(): bool
    {
        return (bool) config('clamav.strict', false) || (bool) config('support_v25.clamav_strict', false);
    }
}
