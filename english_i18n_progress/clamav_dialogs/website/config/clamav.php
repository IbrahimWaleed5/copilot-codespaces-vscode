<?php

/*
|--------------------------------------------------------------------------
| ClamAV virus scanning for every uploaded file
|--------------------------------------------------------------------------
| Recommended on Railway: a separate "clamav" service (Docker image clamav/clamav:stable)
| reached over the private network with clamd's INSTREAM protocol (CLAMAV_HOST / CLAMAV_PORT).
| Without CLAMAV_HOST the local `clamscan` binary is used when it exists.
*/

return [
    'enabled' => (bool) env('CLAMAV_ENABLED', true),

    // clamd over TCP (e.g. clamav.railway.internal:3310)
    'host' => env('CLAMAV_HOST'),
    'port' => (int) env('CLAMAV_PORT', 3310),
    'timeout' => (int) env('CLAMAV_TIMEOUT', 60),

    // Fallback: local binary
    'binary' => env('CLAMAV_BINARY', env('SUPPORT_CLAMAV_BINARY', 'clamscan')),

    // true = refuse uploads while the scanner is unreachable. false = allow and log (safer while starting).
    'strict' => (bool) env('CLAMAV_STRICT', false),

    // Must not exceed clamd StreamMaxLength (ClamAV default 25M). Larger files are not scanned.
    'max_mb' => (int) env('CLAMAV_MAX_MB', 25),

    // Scan every upload in web + API requests (middleware), not only support attachments.
    'scan_all_uploads' => (bool) env('CLAMAV_SCAN_ALL_UPLOADS', true),

    // Alerts: all users with role=admin get a notification + email, plus these extra addresses.
    'alert_emails' => array_values(array_filter(array_map('trim', explode(',', (string) env('CLAMAV_ALERT_EMAILS', ''))))),
    'alert_url' => env('CLAMAV_ALERT_URL', '/notifications'),
    // Flood guard: at most this many alert rounds per hour (detections are still blocked and logged).
    'alerts_per_hour' => (int) env('CLAMAV_ALERTS_PER_HOUR', 30),
];
