<?php

namespace App\Repositories\Contracts;

use App\Models\User;

interface WalletRepositoryInterface
{
    /**
     * Dapatkan informasi saldo dompet pengguna (API-WLT-01, FR-WLT-001).
     */
    public function getWallet(User $user): array;

    /**
     * Dapatkan riwayat mutasi transaksi dompet terpaginasi (API-WLT-02, FR-WLT-004, FR-WLT-005).
     */
    public function getTransactions(User $user, int $perPage = 20): array;

    /**
     * Simulasi isi saldo dengan proteksi idempotency & kunci atomik (API-WLT-03, FR-WLT-006, FR-WLT-009, INV-04).
     */
    public function topup(User $user, int $amount, ?string $idempotencyKey = null, ?string $description = null): array;
}
