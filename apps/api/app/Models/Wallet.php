<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Wallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'available_balance',
        'held_balance',
        'currency',
    ];

    protected function casts(): array
    {
        return [
            'available_balance' => 'integer',
            'held_balance' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Riwayat mutasi dompet.
     */
    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    /**
     * Periksa apakah saldo mencukupi (12_class-diagram.md).
     */
    public function canCover(int $amount): bool
    {
        return $this->available_balance >= $amount;
    }
}
