<?php

namespace App\Http\Middleware;

use App\Services\Security\ClamAvScanner;
use App\Services\Security\MalwareAlertService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * Scans every uploaded file of a web/API request with ClamAV BEFORE the controller stores it.
 * Infected → request refused (422), admins alerted. Scanner down → allowed and logged,
 * or refused (503) when CLAMAV_STRICT=true.
 */
class ScanUploadedFiles
{
    public function __construct(
        private readonly ClamAvScanner $scanner,
        private readonly MalwareAlertService $alerts,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! (bool) config('clamav.enabled', true) || ! (bool) config('clamav.scan_all_uploads', true)) {
            return $next($request);
        }
        $files = array_filter(Arr::flatten($request->allFiles()), fn ($f) => $f instanceof UploadedFile && $f->isValid());
        if ($files === []) {
            return $next($request);
        }

        foreach ($files as $file) {
            $result = $this->scanner->scanPath($file->getRealPath());

            if ($result['status'] === 'infected') {
                $this->alerts->report([
                    'file_name' => $file->getClientOriginalName(),
                    'file_size' => (int) $file->getSize(),
                    'sha256' => hash_file('sha256', $file->getRealPath()) ?: null,
                    'signature' => $result['signature'],
                    'engine' => $result['engine'],
                    'user_id' => $this->uploaderId($request),
                    'ip' => $request->ip(),
                    'route' => mb_substr($request->method() . ' ' . $request->path(), 0, 190),
                ]);
                @unlink($file->getRealPath());

                return $this->refuse($request, 422, 'تم رفض الملف "' . $file->getClientOriginalName() . '" لأن فحص الحماية اكتشف تهديدًا. تم إبلاغ إدارة المنصة.', 'malware_detected');
            }

            if (in_array($result['status'], ['error', 'not_available'], true)) {
                Log::warning('Upload not virus-scanned.', ['status' => $result['status'], 'details' => $result['details'], 'route' => $request->path()]);
                if ((bool) config('clamav.strict', false)) {
                    return $this->refuse($request, 503, 'تعذر فحص الملف أمنيًا الآن. حاول بعد قليل.', 'malware_scanner_unavailable');
                }
            }
        }

        return $next($request);
    }

    /** Web session user, or the API token user (Sanctum) when the route guard has not run yet. */
    private function uploaderId(Request $request): ?int
    {
        try {
            $user = $request->user() ?? (array_key_exists('sanctum', (array) config('auth.guards')) ? $request->user('sanctum') : null);
        } catch (\Throwable) {
            $user = null;
        }

        return $user?->id;
    }

    private function refuse(Request $request, int $status, string $message, string $code): Response
    {
        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json(['success' => false, 'code' => $code, 'message' => $message, 'errors' => ['file' => [$message]]], $status);
        }

        return back()->withInput($request->except(array_keys($request->allFiles())))->withErrors(['file' => $message]);
    }
}
