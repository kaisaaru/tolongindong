<?php

namespace App\Models;

use App\Enums\OrderOfferStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderOffer extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'helper_id',
        'proposed_price',
        'message',
        'offer_status',
        'valid_until',
        'confirmation_expires_at',
    ];

    protected function casts(): array
    {
        return [
            'proposed_price' => 'integer',
            'offer_status' => OrderOfferStatus::class,
            'valid_until' => 'datetime',
            'confirmation_expires_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function helper(): BelongsTo
    {
        return $this->belongsTo(HelperProfile::class, 'helper_id');
    }
}
