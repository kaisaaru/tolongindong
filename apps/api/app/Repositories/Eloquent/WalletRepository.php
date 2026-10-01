<?php

namespace App\Repositories\Eloquent;

use App\Enums\TransactionType;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Repositories\Contracts\WalletRepositoryInterface;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WalletRepository implements WalletRepositoryInterface
{
    /**
     * Dapatkan informasi saldo dompet pengguna (API-WLT-01, FR-WLT-001).
     */
    public function getWallet(User $user): array
    {
        $wallet = Wallet::firstOrCreate(
            ['user_id' => $user->id],
            ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
        );

        return [
            'success' => true,
            'data' => [
                'available_balance' => $wallet->available_balance,
                'held_balance' => $wallet->held_balance,
                'total_balance' => $wallet->available_balance + $wallet->held_balance,
                'currency' => $wallet->currency,
            ],
        ];
    }

    /**
     * Dapatkan riwayat mutasi transaksi dompet terpaginasi (API-WLT-02, FR-WLT-004, FR-WLT-005).
     */
    public function getTransactions(User $user, int $perPage = 20): array
    {
        $wallet = Wallet::firstOrCreate(
            ['user_id' => $user->id],
            ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
        );

        $transactions = $wallet->transactions()
            ->latest('created_at')
            ->paginate($perPage);

        return [
            'success' => true,
            'data' => $transactions,
        ];
    }

    /**
     * Simulasi isi saldo dengan proteksi idempotency & kunci atomik (API-WLT-03, FR-WLT-006, FR-WLT-009, INV-04).
     */
    public function topup(User $user, int $amount, ?string $idempotencyKey = null, ?string $description = null): array
    {
        // Validasi batas minimal isi saldo Rp10.000 (FR-WLT-006)
        if ($amount < 10000) {
            return [
                'success' => false,
                'error_code' => 'INVALID_AMOUNT',
                'message' => 'Nomor transaksi pengisian saldo minimal Rp 10.000.',
                'detail' => ['minimum_amount' => 10000, 'requested_amount' => $amount],
                'status_code' => 422,
            ];
        }

        // Cek proteksi idempotency request ganda (FR-WLT-009, 05_erd-draft.md Bagian 5.2)
        if (!empty($idempotencyKey)) {
            $existingTx = WalletTransaction::where('idempotency_key', $idempotencyKey)->first();

            if ($existingTx) {
                $wallet = $existingTx->wallet;

                return [
                    'success' => true,
                    'data' => [
                        'transaction' => $existingTx,
                        'wallet' => [
                            'available_balance' => $wallet->available_balance,
                            'held_balance' => $wallet->held_balance,
                            'currency' => $wallet->currency,
                        ],
                    ],
                    'message' => 'Transaksi telah diproses sebelumnya (Idempotent Replay).',
                    'status_code' => 200,
                ];
            }
        }

        $key = $idempotencyKey ?: 'topup_' . (string) Str::uuid();

        return DB::transaction(function () use ($user, $amount, $key, $description) {
            // Ambil dompet dengan kunci baris SELECT ... FOR UPDATE (Invarian INV-02)
            $wallet = Wallet::where('user_id', $user->id)->lockForUpdate()->first();

            if (!$wallet) {
                $wallet = Wallet::create([
                    'user_id' => $user->id,
                    'available_balance' => 0,
                    'held_balance' => 0,
                    'currency' => 'IDR',
                ]);
            }

            $newBalance = $wallet->available_balance + $amount;
            $wallet->update(['available_balance' => $newBalance]);

            $tx = WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'transaction_type' => TransactionType::TOPUP,
                'amount' => $amount,
                'balance_after' => $newBalance,
                'idempotency_key' => $key,
                'description' => $description ?: 'Pengisian saldo TD-Wallet sebesar Rp ' . number_format($amount, 0, ',', '.'),
            ]);

            return [
                'success' => true,
                'data' => [
                    'transaction' => $tx,
                    'wallet' => [
                        'available_balance' => $wallet->available_balance,
                        'held_balance' => $wallet->held_balance,
                        'currency' => $wallet->currency,
                    ],
                ],
                'message' => 'Pengisian saldo TD-Wallet berhasil.',
                'status_code' => 201,
            ];
        });
    }
}
