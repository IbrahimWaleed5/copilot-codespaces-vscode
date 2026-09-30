<?php

namespace App\Services\Security;

use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;
use Throwable;

/**
 * Scans files with ClamAV.
 *  - clamd over TCP (INSTREAM) when CLAMAV_HOST is set: fast, the signature database stays loaded.
 *  - otherwise the local clamscan binary, when installed.
 * Result status: clean | infected | error | not_available | skipped.
 */
class ClamAvScanner
{
    /** Same file scanned twice in one request (middleware + attachment service) is scanned once. */
    private static array $memo = [];

    public function mode(): string
    {
        if (filled(config('clamav.host'))) {
            return 'clamd';
        }

        return $this->binaryExists((string) config('clamav.binary', 'clamscan')) ? 'binary' : 'none';
    }

    public function available(): bool
    {
        return match ($this->mode()) {
            'clamd' => $this->ping(),
            'binary' => true,
            default => false,
        };
    }

    public function ping(): bool
    {
        try {
            return trim($this->command('zPING')) === 'PONG';
        } catch (Throwable) {
            return false;
        }
    }

    public function version(): ?string
    {
        try {
            return $this->mode() === 'clamd' ? trim($this->command('zVERSION')) : null;
        } catch (Throwable) {
            return null;
        }
    }

    /** @return array{status:string,signature:?string,details:?string,engine:string} */
    public function scanPath(string $path): array
    {
        $key = is_file($path) ? $path . '|' . filesize($path) . '|' . filemtime($path) : $path;
        if (isset(self::$memo[$key])) {
            return self::$memo[$key];
        }

        return self::$memo[$key] = $this->doScan($path);
    }

    /** Scans bytes held in memory (used by the EICAR self-test). */
    public function scanBytes(string $bytes): array
    {
        if ($this->mode() !== 'clamd') {
            $tmp = tempnam(sys_get_temp_dir(), 'clam');
            file_put_contents($tmp, $bytes);
            try {
                return $this->doScan($tmp);
            } finally {
                @unlink($tmp);
            }
        }

        return $this->instream(fn () => $bytes === '' ? null : [$bytes]);
    }

    private function doScan(string $path): array
    {
        if (! (bool) config('clamav.enabled', true)) {
            return $this->result('not_available', null, 'disabled');
        }
        if (! is_file($path) || ! is_readable($path)) {
            return $this->result('error', null, 'file not readable');
        }
        $maxBytes = max(1, (int) config('clamav.max_mb', 25)) * 1024 * 1024;
        if (filesize($path) > $maxBytes) {
            return $this->result('skipped', null, 'larger than CLAMAV_MAX_MB');
        }

        return match ($this->mode()) {
            'clamd' => $this->instreamFile($path),
            'binary' => $this->binaryScan($path),
            default => $this->result('not_available', null, 'no scanner configured'),
        };
    }

    private function instreamFile(string $path): array
    {
        $handle = fopen($path, 'rb');
        if (! $handle) {
            return $this->result('error', null, 'cannot open file');
        }
        try {
            return $this->instream(function () use ($handle) {
                $chunks = [];
                while (! feof($handle)) {
                    $chunk = fread($handle, 1024 * 256);
                    if ($chunk === false || $chunk === '') {
                        break;
                    }
                    yield $chunk;
                }
            });
        } finally {
            fclose($handle);
        }
    }

    /** clamd INSTREAM: "zINSTREAM\0", then <uint32 length><data>..., then a zero length. */
    private function instream(callable $chunks): array
    {
        try {
            $socket = $this->connect();
            fwrite($socket, "zINSTREAM\0");
            $source = $chunks();
            foreach (is_iterable($source) ? $source : [] as $chunk) {
                if ($chunk === null || $chunk === '') {
                    continue;
                }
                if (fwrite($socket, pack('N', strlen($chunk)) . $chunk) === false) {
                    throw new \RuntimeException('write failed');
                }
            }
            fwrite($socket, pack('N', 0));
            $reply = trim((string) stream_get_contents($socket), "\0\r\n ");
            fclose($socket);
        } catch (Throwable $e) {
            Log::warning('ClamAV scan failed.', ['error' => $e->getMessage()]);

            return $this->result('error', null, 'scanner unreachable');
        }

        // "stream: OK" | "stream: Eicar-Test-Signature FOUND" | "... ERROR"
        if (str_ends_with($reply, 'OK')) {
            return $this->result('clean');
        }
        if (str_ends_with($reply, 'FOUND')) {
            $signature = trim(preg_replace('/^stream:\s*|\s*FOUND$/', '', $reply));

            return $this->result('infected', $signature !== '' ? mb_substr($signature, 0, 200) : 'unknown');
        }
        Log::warning('ClamAV returned an error.', ['reply' => mb_substr($reply, 0, 200)]);

        return $this->result('error', null, mb_substr($reply, 0, 200));
    }

    private function binaryScan(string $path): array
    {
        $process = new Process([(string) config('clamav.binary', 'clamscan'), '--no-summary', $path]);
        $process->setTimeout(max(10, (int) config('clamav.timeout', 60)));
        $process->run();
        $out = trim($process->getOutput() . ' ' . $process->getErrorOutput());

        return match ($process->getExitCode()) {
            0 => $this->result('clean'),
            1 => $this->result('infected', mb_substr(trim(preg_replace('/^.*?:\s*|\s*FOUND.*$/s', '', $out)) ?: $out, 0, 200)),
            default => $this->result('error', null, mb_substr($out, 0, 200)),
        };
    }

    private function command(string $command): string
    {
        $socket = $this->connect();
        fwrite($socket, $command . "\0");
        $reply = trim((string) stream_get_contents($socket), "\0\r\n ");
        fclose($socket);

        return $reply;
    }

    /** @return resource */
    private function connect()
    {
        $host = (string) config('clamav.host');
        $target = filter_var($host, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6) ? "[{$host}]" : $host;
        $timeout = max(5, (int) config('clamav.timeout', 60));
        $socket = @stream_socket_client('tcp://' . $target . ':' . (int) config('clamav.port', 3310), $errno, $error, 10);
        if (! $socket) {
            throw new \RuntimeException("clamd connection failed: {$error}");
        }
        stream_set_timeout($socket, $timeout);

        return $socket;
    }

    private function result(string $status, ?string $signature = null, ?string $details = null): array
    {
        return ['status' => $status, 'signature' => $signature, 'details' => $details, 'engine' => $this->mode()];
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
        @exec($cmd, $o, $code);

        return $code === 0;
    }
}
