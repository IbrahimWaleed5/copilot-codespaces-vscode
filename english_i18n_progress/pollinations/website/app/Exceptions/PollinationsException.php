<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * A Pollinations failure with a safe, user-facing Arabic message.
 * `reason` is a stable code for logic/tests; the message never contains the API key or raw upstream bodies.
 */
class PollinationsException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly string $reason = 'error',
        public readonly int $status = 0,
        public readonly ?int $retryAfter = null,
        public readonly ?string $requestId = null,
    ) {
        parent::__construct($message);
    }

    /** Worth trying the same request again later (not a permanent refusal). */
    public function isTemporary(): bool
    {
        return in_array($this->reason, ['rate_limited', 'timeout', 'upstream', 'unavailable'], true);
    }
}
