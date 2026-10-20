<?php

namespace App\Services;

use App\Enums\TransactionType;
use App\Models\Order;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class EscrowService
{
    /**
     * Menahan saldo pemesan saat tawaran/quote disepakati (FR-WLT-002, INV-02).
     */
    public function holdFunds(User $client, Order $order, int $holdAmount): array
    {
        return DB::transaction(function () use ($client, $order, $holdAmount) {
            $wallet = Wallet::where('user_id', $client->id)->lockForUpdate()->first();

            if (!$wallet || !$wallet->canCover($holdAmount)) {
                return [
                    'success' => false,
                    'error_code' => 'INSUFFICIENT_BALANCE',
                    'message' => 'Saldo TD-Wallet Anda tidak mencukupi untuk menahan biaya pesanan.',
                    'detail' => [
                        'required_amount' => $holdAmount,
                        'available_balance' => $wallet?->available_balance ?? 0,
                    ],
                    'status_code' => 422,
                ];
            }

            $wallet->available_balance -= $holdAmount;
            $wallet->held_balance += $holdAmount;
            $wallet->save();

            $idempotencyKey = 'hold_' . $order->order_number . '_' . Str::random(8);

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'order_id' => $order->id,
                'transaction_type' => TransactionType::HOLD,
                'amount' => $holdAmount,
                'balance_after' => $wallet->available_balance,
                'idempotency_key' => $idempotencyKey,
                'description' => "Penahanan dana pesanan {$order->order_number}",
            ]);

            return [
                'success' => true,
                'data' => [
                    'held_amount' => $holdAmount,
                    'available_balance' => $wallet->available_balance,
                    'held_balance' => $wallet->held_balance,
                ],
            ];
        });
    }

    /**
     * Melepas dana tertahan saat pesanan selesai (FR-WLT-003, INV-02).
     */
    public function releaseFunds(Order $order, array $settlement): array
    {
        return DB::transaction(function () use ($order, $settlement) {
            $clientWallet = Wallet::where('user_id', $order->client_id)->lockForUpdate()->first();
            $helperWallet = Wallet::where('user_id', $order->helper->user_id)->lockForUpdate()->first();

            // 1. Kurangi saldo tertahan client
            if ($clientWallet) {
                $clientWallet->held_balance = max(0, $clientWallet->held_balance - $order->held_amount);

                // Kembalikan sisa dana/talangan ke client jika ada
                if ($settlement['client_refund'] > 0) {
                    $clientWallet->available_balance += $settlement['client_refund'];
                    WalletTransaction::create([
                        'wallet_id' => $clientWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::REFUND,
                        'amount' => $settlement['client_refund'],
                        'balance_after' => $clientWallet->available_balance,
                        'idempotency_key' => 'refund_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Pengembalian sisa dana pesanan {$order->order_number}",
                    ]);
                }

                $clientWallet->save();
            }

            // 2. Berikan upah bersih ke helper
            if ($helperWallet) {
                if ($settlement['helper_payout'] > 0) {
                    $helperWallet->available_balance += $settlement['helper_payout'];
                    WalletTransaction::create([
                        'wallet_id' => $helperWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::RELEASE,
                        'amount' => $settlement['helper_payout'],
                        'balance_after' => $helperWallet->available_balance,
                        'idempotency_key' => 'release_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Pelepasan upah jasa pesanan {$order->order_number}",
                    ]);
                }

                // Penggantian belanja talangan ke helper sebagai baris terpisah (Turunan SA #3, FR-WLT-004)
                if ($settlement['advance_actual'] > 0) {
                    $helperWallet->available_balance += $settlement['advance_actual'];
                    WalletTransaction::create([
                        'wallet_id' => $helperWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::ADVANCE_REIMBURSEMENT,
                        'amount' => $settlement['advance_actual'],
                        'balance_after' => $helperWallet->available_balance,
                        'idempotency_key' => 'adv_reimb_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Penggantian belanja talangan pesanan {$order->order_number}",
                    ]);
                }

                $helperWallet->save();
            }

            return ['success' => true];
        });
    }

    /**
     * Kembalikan dana tertahan saat pesanan dibatalkan (FR-ORD-011, DEC-19).
     */
    public function refundCancellation(Order $order, array $cancellation): array
    {
        return DB::transaction(function () use ($order, $cancellation) {
            $clientWallet = Wallet::where('user_id', $order->client_id)->lockForUpdate()->first();
            $helperWallet = $order->helper ? Wallet::where('user_id', $order->helper->user_id)->lockForUpdate()->first() : null;

            if ($clientWallet) {
                $clientWallet->held_balance = max(0, $clientWallet->held_balance - $order->held_amount);

                if ($cancellation['client_refund'] > 0) {
                    $clientWallet->available_balance += $cancellation['client_refund'];
                    WalletTransaction::create([
                        'wallet_id' => $clientWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::REFUND,
                        'amount' => $cancellation['client_refund'],
                        'balance_after' => $clientWallet->available_balance,
                        'idempotency_key' => 'cancel_refund_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Pengembalian dana pembatalan pesanan {$order->order_number}",
                    ]);
                }

                $clientWallet->save();
            }

            if ($helperWallet) {
                // Kompensasi pembatalan masuk utuh ke helper (DEC-19)
                if ($cancellation['cancellation_fee'] > 0) {
                    $helperWallet->available_balance += $cancellation['cancellation_fee'];
                    WalletTransaction::create([
                        'wallet_id' => $helperWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::CANCELLATION_FEE,
                        'amount' => $cancellation['cancellation_fee'],
                        'balance_after' => $helperWallet->available_balance,
                        'idempotency_key' => 'cancel_fee_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Kompensasi pembatalan pesanan {$order->order_number}",
                    ]);
                }

                if ($cancellation['helper_release'] > $cancellation['cancellation_fee']) {
                    $advanceActual = $cancellation['helper_release'] - $cancellation['cancellation_fee'];
                    $helperWallet->available_balance += $advanceActual;
                    WalletTransaction::create([
                        'wallet_id' => $helperWallet->id,
                        'order_id' => $order->id,
                        'transaction_type' => TransactionType::ADVANCE_REIMBURSEMENT,
                        'amount' => $advanceActual,
                        'balance_after' => $helperWallet->available_balance,
                        'idempotency_key' => 'cancel_adv_' . $order->order_number . '_' . Str::random(8),
                        'description' => "Penggantian talangan sah pembatalan pesanan {$order->order_number}",
                    ]);
                }

                $helperWallet->save();
            }

            return ['success' => true];
        });
    }
}
