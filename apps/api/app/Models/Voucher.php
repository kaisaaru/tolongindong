<?php

namespace App\Models;

use App\Enums\DiscountType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Voucher extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'discount_type',
        'discount_value',
        'max_discount_amount',
        'min_order_amount',
        'usage_limit',
        'category_id',
        'is_active',
        'valid_from',
        'valid_until',
    ];

    protected function casts(): array
    {
        return [
            'discount_type' => DiscountType::class,
            'discount_value' => 'integer',
            'max_discount_amount' => 'integer',
            'min_order_amount' => 'integer',
            'usage_limit' => 'integer',
            'is_active' => 'boolean',
            'valid_from' => 'datetime',
            'valid_until' => 'datetime',
        ];
    }

    public function serviceCategory(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id');
    }

    public function userVouchers(): HasMany
    {
        return $this->hasMany(UserVoucher::class);
    }

    /**
     * Memeriksa apakah voucher masih dalam masa berlaku.
     */
    public function isValidNow(): bool
    {
        $now = now();
        return $this->is_active && $now->gte($this->valid_from) && $now->lte($this->valid_until);
    }

    /**
     * Hitung nilai diskon yang didapat untuk nominal order tertentu (FR-WLT-013).
     */
    public function calculateDiscount(int $orderAmount): int
    {
        if ($orderAmount < $this->min_order_amount) {
            return 0;
        }

        if ($this->discount_type === DiscountType::FIXED) {
            $discount = $this->discount_value;
        } else {
            $discount = (int) floor($orderAmount * $this->discount_value / 100);
        }

        if ($this->max_discount_amount && $discount > $this->max_discount_amount) {
            $discount = $this->max_discount_amount;
        }

        // FR-WLT-013: Diskon maksimal sebesar komisi kotor platform (10% dari order amount)
        $grossCommission = (int) floor($orderAmount * 10 / 100);
        return min($discount, $grossCommission);
    }
}
