<?php

namespace App\Repositories\Contracts;

use App\Enums\OrderStatus;
use App\Models\User;

interface OrderRepositoryInterface
{
    /**
     * Hitung rentang harga acuan sebelum membuat pesanan (API-ORD-01, FR-ORD-002).
     */
    public function calculateEstimate(array $data): array;

    /**
     * Buat pesanan baru (broadcast atau direct booking) (API-ORD-02, FR-ORD-001).
     */
    public function createOrder(User $client, array $data): array;

    /**
     * Dapatkan detail satu pesanan (API-ORD-03, FR-ORD-008).
     */
    public function getOrderDetails(User $user, int $orderId): array;

    /**
     * Dapatkan daftar pesanan milik pengguna (sebagai client atau helper).
     */
    public function listOrders(User $user, array $filters = []): array;

    /**
     * Helper mengajukan penawaran harga (broadcast) atau quote (direct) (API-ORD-04A, DEC-05, DEC-21).
     */
    public function submitOffer(User $helperUser, int $orderId, int $proposedPrice, ?string $message = null): array;

    /**
     * Client memilih salah satu tawaran yang masuk (API-ORD-04C, DEC-05).
     */
    public function selectOffer(User $client, int $orderId, int $offerId): array;

    /**
     * Helper mengonfirmasi kesiapan dalam 60 detik (khusus broadcast) (API-ORD-04D, DEC-21).
     */
    public function confirmOffer(User $helperUser, int $orderId, int $offerId): array;

    /**
     * Helper memajukan status tahapan pesanan (API-ORD-05, FR-ORD-009).
     */
    public function updateStatus(User $user, int $orderId, OrderStatus $targetStatus): array;
    /**
     * Helper mengunggah struk talangan belanja (API-ORD-06, FR-ORD-014, FR-ORD-019).
     */
    public function uploadPriceAdjustment(User $helperUser, int $orderId, int $requestedAmount, ?string $receiptUrl = null): array;

    /**
     * Client menyetujui atau menolak penyesuaian belanja melebihi batas (API-ORD-07, FR-ORD-014, DEC-20).
     */
    public function respondPriceAdjustment(User $client, int $orderId, int $adjustmentId, string $action): array;

    /**
     * Client atau helper mengajukan sengketa pesanan Delivery (API-ORD-12, FR-ORD-018, DEC-10).
     */
    public function raiseDispute(User $user, int $orderId, string $reason): array;

    /**
     * Admin menyelesaikan sengketa Delivery (API-ADM-06, FR-ADM-006, DEC-24).
     */
    public function resolveDispute(User $admin, int $disputeId, string $resolution, ?string $adminNote = null): array;

    /**
     * Client memberikan penilaian satu arah ke Helper (FR-RTG-001, DEC-09).
     */
    public function submitRating(User $client, int $orderId, int $score, ?string $review = null): array;

    /**
     * Client mengonfirmasi pekerjaan selesai & settlement dana (API-ORD-08, FR-ORD-010).
     */
    public function confirmCompletion(User $client, int $orderId): array;

    /**
     * Membatalkan pesanan dengan aturan denda/kompensasi (API-ORD-09, FR-ORD-011, DEC-19).
     */
    public function cancelOrder(User $user, int $orderId, ?string $reason = null): array;
}
