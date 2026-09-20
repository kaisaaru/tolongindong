<?php

namespace App\Models;

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
            'is_available' => 'boolean',
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
     * Helper status approved check.
     */
    public function isApproved(): bool
    {
        return !is_null($this->approved_at);
    }
}
