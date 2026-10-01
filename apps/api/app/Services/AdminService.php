<?php

namespace App\Services;

use App\Enums\AdminActionType;
use App\Enums\OrderOfferStatus;
use App\Enums\OrderStatus;
use App\Models\AdminActionLog;
use App\Models\Order;
use App\Models\OrderOffer;
use App\Models\OrderStatusHistory;
use App\Models\ServiceCategory;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class AdminService
{
    public function __construct(
        protected EscrowService $escrowService
    ) {}

    /**
     * Membekukan (suspend) akun pengguna (API-ADM-08, FR-ADM-009, DEC-22).
     */
    public function suspendUser(User $admin, string $targetUserId, string $reason): array
    {
        $targetUser = User::find($targetUserId);

        if (!$targetUser) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pengguna tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if ($targetUser->is_admin) {
            return [
                'success' => false,
                'error_code' => 'CANNOT_SUSPEND_ADMIN',
                'message' => 'Tidak dapat membekukan sesama akun administrator.',
                'status_code' => 422,
            ];
        }

        // DEC-22: Suspend ditolak kalau pengguna masih punya order berstatus aktif atau disputed
        $activeStatuses = [
            OrderStatus::PENDING_CONFIRMATION->value,
            OrderStatus::ACCEPTED->value,
            OrderStatus::ON_THE_WAY->value,
            OrderStatus::ARRIVED->value,
            OrderStatus::IN_PROGRESS->value,
            OrderStatus::PRICE_ADJUSTMENT->value,
            OrderStatus::AWAITING_CONFIRMATION->value,
            OrderStatus::DISPUTED->value,
        ];

        $clientHasActive = $targetUser->orders()->whereIn('status', $activeStatuses)->exists();
        $helperHasActive = $targetUser->helperProfile && $targetUser->helperProfile->orders()->whereIn('status', $activeStatuses)->exists();

        if ($clientHasActive || $helperHasActive) {
            return [
                'success' => false,
                'error_code' => 'ACTIVE_ORDERS_EXIST',
                'message' => 'Akun tidak dapat dinonaktifkan karena masih memiliki pesanan yang sedang berjalan atau dalam sengketa.',
                'status_code' => 409,
            ];
        }

        return DB::transaction(function () use ($admin, $targetUser, $reason) {
            $targetUser->update([
                'is_suspended' => true,
                'suspended_reason' => $reason,
            ]);

            // Batalkan pesanan client yang masih mencari helper atau menunggu quote (DEC-14 no 12)
            $targetUser->orders()
                ->whereIn('status', [OrderStatus::SEARCHING->value, OrderStatus::AWAITING_QUOTE->value])
                ->update(['status' => OrderStatus::CANCELLED_BY_ADMIN->value]);

            // Tarik seluruh tawaran helper yang masih diajukan
            if ($targetUser->helperProfile) {
                OrderOffer::where('helper_id', $targetUser->helperProfile->id)
                    ->where('offer_status', OrderOfferStatus::SUBMITTED->value)
                    ->update(['offer_status' => OrderOfferStatus::WITHDRAWN->value]);
            }

            // Cabut seluruh sesi token login
            $targetUser->tokens()->delete();

            // Catat log tindakan admin (FR-ADM-008)
            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => AdminActionType::SUSPEND_ACCOUNT,
                'target_entity' => 'users',
                'target_id' => (string) $targetUser->id,
                'note' => $reason,
            ]);

            return [
                'success' => true,
                'data' => $targetUser->fresh(),
                'message' => 'Akun pengguna berhasil dinonaktifkan (suspend).',
            ];
        });
    }

    /**
     * Mengaktifkan kembali (reactivate) akun yang di-suspend (API-ADM-09, FR-ADM-010).
     */
    public function reactivateUser(User $admin, string $targetUserId): array
    {
        $targetUser = User::find($targetUserId);

        if (!$targetUser) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pengguna tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$targetUser->is_suspended) {
            return [
                'success' => false,
                'error_code' => 'USER_NOT_SUSPENDED',
                'message' => 'Akun pengguna ini tidak sedang dinonaktifkan.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($admin, $targetUser) {
            $targetUser->update([
                'is_suspended' => false,
                'suspended_reason' => null,
            ]);

            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => AdminActionType::REACTIVATE_ACCOUNT,
                'target_entity' => 'users',
                'target_id' => (string) $targetUser->id,
                'note' => 'Akun pengguna diaktifkan kembali oleh administrator.',
            ]);

            return [
                'success' => true,
                'data' => $targetUser->fresh(),
                'message' => 'Akun pengguna berhasil diaktifkan kembali.',
            ];
        });
    }

    /**
     * Admin membatalkan pesanan aktif (API-ADM-10, FR-ADM-011, DEC-22).
     */
    public function cancelOrder(User $admin, int $orderId, string $reason): array
    {
        $order = Order::find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if ($order->status === OrderStatus::DISPUTED) {
            return [
                'success' => false,
                'error_code' => 'ORDER_IN_DISPUTE',
                'message' => 'Pesanan sedang dalam sengketa, silakan gunakan menu putusan sengketa.',
                'status_code' => 409,
            ];
        }

        if ($order->isTerminal()) {
            return [
                'success' => false,
                'error_code' => 'ORDER_ALREADY_FINAL',
                'message' => 'Pesanan sudah berstatus final (selesai atau dibatalkan sebelumnya).',
                'status_code' => 409,
            ];
        }

        return DB::transaction(function () use ($admin, $order, $reason) {
            // DEC-22 / FR-ADM-011: Dana jasa kembali penuh ke client, helper tidak menerima kompensasi, talangan sah tetap diganti
            $helperRelease = $order->advance_actual;
            $clientRefund = max(0, $order->held_amount - $helperRelease);

            if ($order->held_amount > 0) {
                $this->escrowService->refundCancellation($order, [
                    'client_refund' => $clientRefund,
                    'helper_release' => $helperRelease,
                    'cancellation_fee' => 0,
                ]);
            }

            $order->update([
                'status' => OrderStatus::CANCELLED_BY_ADMIN,
                'cancellation_fee' => 0,
            ]);

            OrderStatusHistory::create([
                'order_id' => $order->id,
                'from_status' => $order->status,
                'to_status' => OrderStatus::CANCELLED_BY_ADMIN,
                'changed_by_user_id' => $admin->id,
                'note' => "Pesanan dibatalkan oleh admin: {$reason}",
            ]);

            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => AdminActionType::CANCEL_ORDER,
                'target_entity' => 'orders',
                'target_id' => (string) $order->id,
                'note' => $reason,
            ]);

            return [
                'success' => true,
                'data' => [
                    'order' => $order->fresh(),
                    'client_refund' => $clientRefund,
                    'helper_reimbursement' => $helperRelease,
                ],
                'message' => 'Pesanan berhasil dibatalkan oleh admin.',
            ];
        });
    }

    /**
     * Ringkasan pendapatan komisi platform (API-ADM-07, FR-ADM-007).
     */
    public function commissionSummary(?string $startDate = null, ?string $endDate = null): array
    {
        $query = Order::where('status', OrderStatus::COMPLETED->value);

        if ($startDate) {
            $query->where('created_at', '>=', Carbon::parse($startDate)->startOfDay());
        }

        if ($endDate) {
            $query->where('created_at', '<=', Carbon::parse($endDate)->endOfDay());
        }

        $totalCommission = (int) $query->sum('platform_commission');
        $completedCount = (int) $query->count();
        $totalVolume = (int) $query->sum('total_amount');

        // Rincian komisi per kategori
        $breakdown = ServiceCategory::select('service_categories.id', 'service_categories.name', 'service_categories.code')
            ->selectRaw('COUNT(orders.id) as orders_count')
            ->selectRaw('COALESCE(SUM(orders.platform_commission), 0) as commission_amount')
            ->leftJoin('orders', function ($join) use ($startDate, $endDate) {
                $join->on('orders.category_id', '=', 'service_categories.id')
                    ->where('orders.status', '=', OrderStatus::COMPLETED->value);

                if ($startDate) {
                    $join->where('orders.created_at', '>=', Carbon::parse($startDate)->startOfDay());
                }
                if ($endDate) {
                    $join->where('orders.created_at', '<=', Carbon::parse($endDate)->endOfDay());
                }
            })
            ->groupBy('service_categories.id', 'service_categories.name', 'service_categories.code')
            ->get()
            ->map(fn ($item) => [
                'category_id' => $item->id,
                'category_name' => $item->name,
                'category_code' => $item->code,
                'orders_count' => (int) $item->orders_count,
                'commission_amount' => (int) $item->commission_amount,
            ]);

        return [
            'success' => true,
            'data' => [
                'period' => [
                    'start_date' => $startDate,
                    'end_date' => $endDate,
                ],
                'total_commission' => $totalCommission,
                'completed_orders_count' => $completedCount,
                'total_transaction_volume' => $totalVolume,
                'category_breakdown' => $breakdown,
            ],
            'message' => 'Ringkasan komisi platform berhasil dimuat.',
        ];
    }
}
