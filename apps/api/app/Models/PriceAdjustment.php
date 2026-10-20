<?php

namespace App\Models;

use App\Enums\PriceAdjustmentStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PriceAdjustment extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'receipt_attachment_id',
        'requested_amount',
        'recognized_amount',
        'additional_hold_amount',
        'approval_status',
    ];

    protected function casts(): array
    {
        return [
            'requested_amount' => 'integer',
            'recognized_amount' => 'integer',
            'additional_hold_amount' => 'integer',
            'approval_status' => PriceAdjustmentStatus::class,
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function receiptAttachment(): BelongsTo
    {
        return $this->belongsTo(OrderAttachment::class, 'receipt_attachment_id');
    }
}
