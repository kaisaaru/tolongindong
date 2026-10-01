<?php

namespace App\Models;

use App\Enums\DisputeResolution;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Dispute extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'raised_by_user_id',
        'reason',
        'resolution',
        'client_refund_amount',
        'helper_release_amount',
        'admin_note',
        'resolved_by_admin_id',
        'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'resolution' => DisputeResolution::class,
            'client_refund_amount' => 'integer',
            'helper_release_amount' => 'integer',
            'resolved_at' => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function raisedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'raised_by_user_id');
    }

    public function resolvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by_admin_id');
    }
}
