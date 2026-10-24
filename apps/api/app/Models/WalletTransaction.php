<?php

namespace App\Models;

use App\Enums\TransactionType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletTransaction extends Model
{
    use HasFactory;

    // Bersifat append-only (05_erd-draft.md Bagian 5.2 Invarian Dompet)
    const UPDATED_AT = null;

    protected $fillable = [
        'wallet_id',
        'order_id',
        'transaction_type',
        'amount',
        'balance_after',
        'idempotency_key',
        'description',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'transaction_type' => TransactionType::class,
            'amount' => 'integer',
            'balance_after' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    /**
     * Dompet pemilik transaksi.
     */
    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }
}
