<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserVoucher extends Model
{
    use HasFactory;

    const UPDATED_AT = null;

    protected $fillable = [
        'user_id',
        'voucher_id',
        'used_order_id',
        'discount_applied',
        'used_at',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'discount_applied' => 'integer',
            'used_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function voucher(): BelongsTo
    {
        return $this->belongsTo(Voucher::class);
    }

    public function usedOrder(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'used_order_id');
    }

    public function isUsed(): bool
    {
        return !is_null($this->used_order_id);
    }
}
