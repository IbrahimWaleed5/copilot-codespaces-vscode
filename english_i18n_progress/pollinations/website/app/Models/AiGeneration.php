<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiGeneration extends Model
{
    public const PROCESSING = 'processing';
    public const COMPLETED = 'completed';
    public const FAILED = 'failed';

    protected $fillable = [
        'user_id', 'project_id', 'support_ticket_id', 'support_message_id', 'ai_usage_log_id',
        'type', 'kind', 'provider', 'model', 'prompt', 'status',
        'output_path', 'output_url', 'output_mime', 'output_size',
        'error_code', 'error_message', 'metadata', 'completed_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'output_size' => 'integer',
        'completed_at' => 'datetime',
    ];

    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function supportTicket(): BelongsTo { return $this->belongsTo(SupportTicket::class); }
}
