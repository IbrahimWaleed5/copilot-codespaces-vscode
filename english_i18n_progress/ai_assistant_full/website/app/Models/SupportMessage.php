<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportMessage extends Model
{
    protected $fillable = [
        'support_ticket_id',
        'sender_id',
        'sender_type',
        'message',
        'email_subject',
        'template_key',
        'delivery_channels',
        'email_sent_at',
        'message_type',
        'is_internal',
        'attachment_path',
        'attachment_name',
        'attachment_mime',
        'attachment_size',
        'read_at',
        'source_channel',
        'provider_message_id',
        'scan_status',
        'ai_thinking',
    ];

    protected $casts = [
        'is_internal' => 'boolean',
        'read_at' => 'datetime',
        'delivery_channels' => 'array',
        'email_sent_at' => 'datetime',
    ];

    protected $appends = [
        'attachment_url',
        'attachment_api_url',
        'secure_attachment_url',
    ];

    public function getAttachmentUrlAttribute(): ?string
    {
        if (! filled($this->attachment_path) || ! $this->exists) {
            return null;
        }

        return route('support.messages.attachment', [
            'supportMessage' => $this->getKey(),
        ]);
    }

    public function getAttachmentApiUrlAttribute(): ?string
    {
        if (! filled($this->attachment_path) || ! $this->exists) {
            return null;
        }

        return url('/api/support/messages/' . $this->getKey() . '/attachment');
    }


    public function getSecureAttachmentUrlAttribute(): ?string
    {
        if (! filled($this->attachment_path) || ! $this->exists) return null;
        return \Illuminate\Support\Facades\URL::temporarySignedRoute(
            'support.secure-attachment', now()->addMinutes(10), ['supportMessage'=>$this->getKey()]
        );
    }

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(
            SupportTicket::class,
            'support_ticket_id'
        );
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(
            User::class,
            'sender_id'
        );
    }

    public function hasAttachment(): bool
    {
        return filled($this->attachment_path);
    }

    public function isFromBot(): bool
    {
        return $this->sender_type === 'bot';
    }

    public function isFromCustomer(): bool
    {
        return $this->sender_type === 'customer';
    }

    public function isFromEmployee(): bool
    {
        return in_array(
            $this->sender_type,
            ['employee', 'admin'],
            true
        );
    }
}
