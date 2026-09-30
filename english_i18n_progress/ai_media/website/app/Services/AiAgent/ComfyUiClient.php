<?php

namespace App\Services\AiAgent;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Minimal ComfyUI HTTP client: queue a workflow, read its history, download the output file.
 * Workflows are the "Save (API Format)" JSON with {{PROMPT}}, {{NEGATIVE}} and {{SEED}} placeholders.
 */
class ComfyUiClient
{
    public function configured(string $workflowKey): bool
    {
        $url = (string) config('ai_media.self_hosted.url');
        $workflow = (string) config('ai_media.self_hosted.' . $workflowKey);

        return $url !== '' && $workflow !== '' && is_file($workflow);
    }

    /** Queues the workflow and returns the ComfyUI prompt id. */
    public function queue(string $workflowKey, string $prompt, string $negative = ''): string
    {
        $path = (string) config('ai_media.self_hosted.' . $workflowKey);
        $template = is_file($path) ? (string) file_get_contents($path) : '';
        if (trim($template) === '') {
            throw new RuntimeException('ملف workflow الخاص بـ ComfyUI غير موجود.');
        }

        // Values are inserted JSON-escaped so quotes/new lines in the prompt cannot break the workflow.
        $escape = static fn (string $v): string => substr(json_encode($v, JSON_UNESCAPED_UNICODE), 1, -1);
        $json = strtr($template, [
            '{{PROMPT}}' => $escape($prompt),
            '{{NEGATIVE}}' => $escape($negative),
            '"{{SEED}}"' => (string) random_int(1, 2_000_000_000),
            '{{SEED}}' => (string) random_int(1, 2_000_000_000),
        ]);
        $workflow = json_decode($json, true);
        if (! is_array($workflow)) {
            throw new RuntimeException('ملف workflow الخاص بـ ComfyUI ليس JSON صالحًا.');
        }

        $response = $this->http(30)->post($this->url('/prompt'), [
            'prompt' => $workflow,
            'client_id' => (string) Str::uuid(),
        ]);
        $id = (string) $response->json('prompt_id', '');
        if (! $response->successful() || $id === '') {
            throw new RuntimeException('رفض خادم ComfyUI الطلب (' . $response->status() . ').');
        }

        return $id;
    }

    /**
     * @return array{done:bool,bytes?:string,mime?:string,error?:string}
     */
    public function result(string $promptId, array $kinds = ['images']): array
    {
        $response = $this->http(20)->get($this->url('/history/' . rawurlencode($promptId)));
        if (! $response->successful()) {
            return ['done' => false];
        }
        $entry = $response->json($promptId);
        if (! is_array($entry)) {
            return ['done' => false];
        }
        if (($entry['status']['status_str'] ?? '') === 'error') {
            return ['done' => true, 'error' => 'فشل تنفيذ workflow على خادم ComfyUI.'];
        }

        foreach (($entry['outputs'] ?? []) as $output) {
            foreach ($kinds as $kind) {
                foreach (($output[$kind] ?? []) as $file) {
                    if (! is_array($file) || empty($file['filename'])) {
                        continue;
                    }
                    $view = $this->http(120)->get($this->url('/view'), [
                        'filename' => $file['filename'],
                        'subfolder' => $file['subfolder'] ?? '',
                        'type' => $file['type'] ?? 'output',
                    ]);
                    if ($view->successful() && $view->body() !== '') {
                        return [
                            'done' => true,
                            'bytes' => $view->body(),
                            'mime' => $this->mimeFor((string) $file['filename'], (string) $view->header('Content-Type')),
                        ];
                    }
                }
            }
        }

        // Still running, or finished without an output node we can read.
        return (bool) ($entry['status']['completed'] ?? false)
            ? ['done' => true, 'error' => 'خادم ComfyUI أنهى التنفيذ بدون ملف ناتج.']
            : ['done' => false];
    }

    private function mimeFor(string $name, string $header): string
    {
        $header = strtolower(trim(explode(';', $header)[0]));
        if (str_starts_with($header, 'image/') || str_starts_with($header, 'video/')) {
            return $header;
        }

        return match (strtolower(pathinfo($name, PATHINFO_EXTENSION))) {
            'jpg', 'jpeg' => 'image/jpeg',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            'mp4' => 'video/mp4',
            'webm' => 'video/webm',
            default => 'image/png',
        };
    }

    private function url(string $path): string
    {
        return rtrim((string) config('ai_media.self_hosted.url'), '/') . $path;
    }

    private function http(int $timeout)
    {
        $request = Http::acceptJson()->timeout($timeout);
        $token = trim((string) config('ai_media.self_hosted.token'));

        return $token !== '' ? $request->withToken($token) : $request;
    }
}
