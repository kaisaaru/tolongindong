<?php

namespace App\Models;

use App\Enums\BookingType;
use App\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_number',
        'client_id',
        'helper_id',
        'category_id',
        'booking_type',
        'status',
        'task_description',
        'pickup_address_id',
        'destination_address_id',
        'client_estimated_price',
        'base_fee',
        'distance_fee',
        'service_fee',
        'total_amount',
        'voucher_discount',
        'service_client_charge',
        'advance_limit',
        'held_amount',
        'advance_actual',
        'helper_payout',
        'platform_commission',
        'cancellation_fee',
        'offer_window_expires_at',
        'helper_finished_at',
    ];

    protected function casts(): array
    {
        return [
            'booking_type' => BookingType::class,
            'status' => OrderStatus::class,
            'client_estimated_price' => 'integer',
            'base_fee' => 'integer',
            'distance_fee' => 'integer',
            'service_fee' => 'integer',
            'total_amount' => 'integer',
            'voucher_discount' => 'integer',
            'service_client_charge' => 'integer',
            'advance_limit' => 'integer',
            'held_amount' => 'integer',
            'advance_actual' => 'integer',
            'helper_payout' => 'integer',
            'platform_commission' => 'integer',
            'cancellation_fee' => 'integer',
            'offer_window_expires_at' => 'datetime',
            'helper_finished_at' => 'datetime',
        ];
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(User::class, 'client_id');
    }

    public function helper(): BelongsTo
    {
        return $this->belongsTo(HelperProfile::class, 'helper_id');
    }

    public function serviceCategory(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id');
    }

    public function pickupAddress(): BelongsTo
    {
        return $this->belongsTo(Address::class, 'pickup_address_id');
    }

    public function destinationAddress(): BelongsTo
    {
        return $this->belongsTo(Address::class, 'destination_address_id');
    }

    public function offers(): HasMany
    {
        return $this->hasMany(OrderOffer::class);
    }

    public function statusHistories(): HasMany
    {
        return $this->hasMany(OrderStatusHistory::class);
    }

    public function attachments(): HasMany
    {
        return $this->hasMany(OrderAttachment::class);
    }

    public function priceAdjustments(): HasMany
    {
        return $this->hasMany(PriceAdjustment::class);
    }

    public function dispute(): HasOne
    {
        return $this->hasOne(Dispute::class);
    }

    public function rating(): HasOne
    {
        return $this->hasOne(Rating::class);
    }

    public function isBroadcast(): bool
    {
        return $this->booking_type === BookingType::BROADCAST;
    }

    public function isDirect(): bool
    {
        return $this->booking_type === BookingType::DIRECT;
    }

    public function isActive(): bool
    {
        return $this->status->isActive();
    }

    public function isTerminal(): bool
    {
        return $this->status->isTerminal();
    }
}
