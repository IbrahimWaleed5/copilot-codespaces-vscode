<?php

namespace App\Console\Commands;

use App\Services\Security\ClamAvScanner;
use App\Services\Security\MalwareAlertService;
use Illuminate\Console\Command;

/**
 * php artisan clamav:check          → connection + version + EICAR test (harmless standard test string)
 * php artisan clamav:check --alert  → also sends a TEST alert (notification + email) to the admins
 */
class ClamAvCheck extends Command
{
    protected $signature = 'clamav:check {--alert : Send a test alert to the admins}';

    protected $description = 'Check the ClamAV scanner connection and detection (EICAR test).';

    public function handle(ClamAvScanner $scanner, MalwareAlertService $alerts): int
    {
        $mode = $scanner->mode();
        $this->line('Mode: ' . $mode . ($mode === 'clamd' ? ' (' . config('clamav.host') . ':' . config('clamav.port') . ')' : ''));
        if ($mode === 'none') {
            $this->error('No scanner: set CLAMAV_HOST (Railway ClamAV service) or install clamscan.');

            return self::FAILURE;
        }
        if ($mode === 'clamd') {
            if (! $scanner->ping()) {
                $this->error('clamd did not answer PING. Check CLAMAV_HOST / CLAMAV_PORT and that the ClamAV service is running.');

                return self::FAILURE;
            }
            $this->info('PING → PONG. ' . ($scanner->version() ?? ''));
        }

        // EICAR: the industry-standard harmless test string every antivirus detects (built in pieces on purpose).
        $eicar = 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$' . 'EICAR-STANDARD-ANTIVIRUS' . '-TEST-FILE!$H+H*';
        $result = $scanner->scanBytes($eicar);
        if ($result['status'] !== 'infected') {
            $this->error('EICAR test was NOT detected (status: ' . $result['status'] . ($result['details'] ? ', ' . $result['details'] : '') . ').');

            return self::FAILURE;
        }
        $this->info('EICAR detected: ' . $result['signature'] . ' ✔');
        $clean = $scanner->scanBytes('hello from Alwaleed platform');
        $this->line('Clean sample: ' . $clean['status']);

        if ($this->option('alert')) {
            $alerts->report([
                'file_name' => 'eicar-test.txt',
                'file_size' => strlen($eicar),
                'sha256' => hash('sha256', $eicar),
                'signature' => $result['signature'] . ' (TEST)',
                'engine' => $mode,
                'route' => 'artisan clamav:check --alert',
                'context' => ['test' => true],
            ]);
            $this->info('Test alert sent to admins (notification + email).');
        }

        return self::SUCCESS;
    }
}
