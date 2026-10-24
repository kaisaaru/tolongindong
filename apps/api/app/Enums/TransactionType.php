<?php

namespace App\Enums;

enum TransactionType: string
{
    case TOPUP = 'topup';
    case HOLD = 'hold';
    case RELEASE = 'release';
    case ADVANCE_REIMBURSEMENT = 'advance_reimbursement';
    case REFUND = 'refund';
    case PAYOUT = 'payout';
    case CANCELLATION_FEE = 'cancellation_fee';

    /**
     * Deskripsi jenis transaksi untuk laporan/tampilan.
     */
    public function label(): string
    {
        return match ($this) {
            self::TOPUP => 'Isi Saldo (Top Up)',
            self::HOLD => 'Penahanan Dana Escrow',
            self::RELEASE => 'Pelepasan Dana Escrow',
            self::ADVANCE_REIMBURSEMENT => 'Penggantian Talangan Belanja',
            self::REFUND => 'Pengembalian Dana ke Pemesan',
            self::PAYOUT => 'Pencairan Upah Bersih Helper',
            self::CANCELLATION_FEE => 'Kompensasi Pembatalan Pesanan',
        };
    }

    /**
     * Dapatkan semua nilai string enum.
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
