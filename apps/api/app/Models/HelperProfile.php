<?php

namespace App\Models;

use App\Enums\HelperAvailability;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class HelperProfile extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'hourly_rate',
        'is_available',
        'rating_average',
        'rating_count',
        'completed_order_count',
        'cancelled_order_count',
        'max_advance_limit',
        'approved_at',
    ];

    protected function casts(): array
    {
        return [
            'hourly_rate' => 'integer',
            'is_available' => HelperAvailability::class,
            'rating_average' => 'decimal:2',
            'rating_count' => 'integer',
            'completed_order_count' => 'integer',
            'cancelled_order_count' => 'integer',
            'max_advance_limit' => 'integer',
            'approved_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function serviceCategories(): BelongsToMany
    {
        return $this->belongsToMany(
            ServiceCategory::class,
            'helper_service_category',
            'helper_profile_id',
            'service_category_id'
        );
    }

    /**
     * Pesanan yang dikerjakan sebagai Helper.
     */
    public function orders(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Order::class, 'helper_id');
    }

    /**
     * Penilaian yang diterima dari client (FR-RTG-001).
     */
    public function ratings(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(Rating::class, 'helper_id');
    }

    /**
     * Helper status approved check.
     */
    public function isApproved(): bool
    {
        return !is_null($this->approved_at);
    }

    /**
     * Set availability fleksibel (menerima boolean atau enum string).
     */
    public function setIsAvailableAttribute(mixed $value): void
    {
        if (is_bool($value)) {
            $this->attributes['is_available'] = $value ? HelperAvailability::AVAILABLE->value : HelperAvailability::UNAVAILABLE->value;
        } elseif ($value instanceof HelperAvailability) {
            $this->attributes['is_available'] = $value->value;
        } else {
            $this->attributes['is_available'] = (string) $value;
        }
    }

    /**
     * Periksa apakah helper berstatus available.
     */
    public function isAvailable(): bool
    {
        return $this->is_available === HelperAvailability::AVAILABLE;
    }

    /**
     * Memeriksa apakah helper berhak menerima pesanan (12_class-diagram.md).
     */
    public function canAcceptOrders(): bool
    {
        return $this->isAvailable() && $this->isApproved();
    }

    /**
     * Periksa apakah batas talangan helper mencukupi (DEC-17, 12_class-diagram.md).
     */
    public function coversAdvanceLimit(int $advanceLimit): bool
    {
        return $this->max_advance_limit >= $advanceLimit;
    }

    /**
     * Hitung ulang rating rata-rata dari seluruh penilaian (DEC-09, 12_class-diagram.md).
     */
    public function recalculateRating(): void
    {
        $avg = (float) $this->ratings()->avg('score') ?: 0.0;
        $count = $this->ratings()->count();

        $this->update([
            'rating_average' => round($avg, 2),
            'rating_count' => $count,
        ]);
    }
}
