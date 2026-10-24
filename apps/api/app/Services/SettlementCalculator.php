<?php

namespace App\Services;

use App\Enums\OrderStatus;

class SettlementCalculator
{
    /**
     * Hitung alokasi dana saat penahanan awal (05_erd-draft.md Bagian 2.2).
     */
    public function calculateHold(int $totalAmount, int $advanceLimit, int $voucherValue = 0): array
    {
        $grossCommission = (int) floor($totalAmount * 10 / 100);
        $voucherDiscount = min($voucherValue, $grossCommission);
        $serviceClientCharge = max(0, $totalAmount - $voucherDiscount);
        $heldAmount = $serviceClientCharge + $advanceLimit;

        return [
            'total_amount' => $totalAmount,
            'gross_commission' => $grossCommission,
            'voucher_discount' => $voucherDiscount,
            'service_client_charge' => $serviceClientCharge,
            'advance_limit' => $advanceLimit,
            'held_amount' => $heldAmount,
        ];
    }

    /**
     * Hitung penyelesaian dana saat pesanan selesai / favor helper (05_erd-draft.md Bagian 2.2).
     */
    public function calculateCompletion(int $totalAmount, int $heldAmount, int $advanceActual, int $voucherDiscount = 0): array
    {
        $grossCommission = (int) floor($totalAmount * 10 / 100);
        $helperPayout = $totalAmount - $grossCommission;
        $platformCommission = max(0, $grossCommission - $voucherDiscount);
        $helperRelease = $helperPayout + $advanceActual;
        $clientRefund = max(0, $heldAmount - $helperRelease - $platformCommission);

        return [
            'helper_payout' => $helperPayout,
            'advance_actual' => $advanceActual,
            'helper_release' => $helperRelease,
            'platform_commission' => $platformCommission,
            'client_refund' => $clientRefund,
        ];
    }

    /**
     * Hitung pembatalan pesanan (05_erd-draft.md Bagian 2.2).
     */
    public function calculateCancellation(int $heldAmount, int $advanceActual, int $cancellationFee): array
    {
        $helperRelease = $advanceActual + $cancellationFee;
        $platformCommission = 0;
        $clientRefund = max(0, $heldAmount - $helperRelease);

        return [
            'helper_release' => $helperRelease,
            'platform_commission' => $platformCommission,
            'client_refund' => $clientRefund,
            'cancellation_fee' => $cancellationFee,
        ];
    }

    /**
     * Hitung sengketa split 50:50 (Turunan SA #8, 05_erd-draft.md Bagian 2.2).
     * Aturan selisih Rp1: helper_release = floor(held_amount / 2), sisa ke client.
     */
    public function calculateSplit(int $heldAmount): array
    {
        $helperRelease = (int) intdiv($heldAmount, 2);
        $clientRefund = $heldAmount - $helperRelease;
        $platformCommission = 0;

        return [
            'helper_release' => $helperRelease,
            'client_refund' => $clientRefund,
            'platform_commission' => $platformCommission,
        ];
    }

    /**
     * Hitung denda kompensasi pembatalan oleh client (FR-ORD-011, DEC-19, Turunan SA #7).
     */
    public function calculateCancellationFee(OrderStatus $status, int $acceptedSeconds, int $totalAmount, int $serviceClientCharge): int
    {
        $fee = 0;

        if ($status === OrderStatus::ACCEPTED) {
            // Gratis jika kurang dari 120 detik, Rp5.000 jika 120 detik atau lebih
            if ($acceptedSeconds >= 120) {
                $fee = 5000;
            }
        } elseif ($status === OrderStatus::ON_THE_WAY || $status === OrderStatus::ARRIVED) {
            // 25% dari total harga jasa
            $fee = (int) floor($totalAmount * 0.25);
        }

        // Turunan SA #7: kompensasi dibatasi maksimal service_client_charge
        return min($fee, $serviceClientCharge);
    }
}
