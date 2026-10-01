<?php

namespace App\Models;

use App\Enums\AttachmentType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderAttachment extends Model
{
    use HasFactory;

    const UPDATED_AT = null;

    protected $fillable = [
        'order_id',
        'uploader_user_id',
        'attachment_type',
        'file_url',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'attachment_type' => AttachmentType::class,
            'created_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function uploaderUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploader_user_id');
    }
}
