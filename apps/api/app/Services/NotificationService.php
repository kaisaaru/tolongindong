<?php

namespace App\Services;

use App\Enums\NotificationType;
use App\Models\Notification;
use App\Models\User;

class NotificationService
{
    /**
     * Buat dan simpan notifikasi baru untuk pengguna (FR-NOT-002, FR-NOT-004).
     */
    public static function createNotification(string $userId, NotificationType $type, string $title, string $body, ?int $orderId = null): Notification
    {
        return Notification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'reference_order_id' => $orderId,
        ]);
    }

    /**
     * Tampilkan riwayat notifikasi pengguna dengan penanda unread (FR-NOT-001, FR-NOT-005).
     */
    public function listUserNotifications(User $user, int $perPage = 20): array
    {
        $unreadCount = $user->notifications()->whereNull('read_at')->count();

        $notifications = $user->notifications()
            ->latest('created_at')
            ->paginate($perPage);

        return [
            'success' => true,
            'data' => [
                'unread_count' => $unreadCount,
                'notifications' => $notifications,
            ],
            'message' => 'Daftar notifikasi berhasil dimuat.',
        ];
    }

    /**
     * Tandai satu notifikasi telah dibaca.
     */
    public function markAsRead(User $user, int $id): array
    {
        $notification = $user->notifications()->find($id);

        if (!$notification) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Notifikasi tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        $notification->markAsRead();

        return [
            'success' => true,
            'data' => $notification->fresh(),
            'message' => 'Notifikasi ditandai sebagai sudah dibaca.',
        ];
    }

    /**
     * Tandai seluruh notifikasi pengguna telah dibaca.
     */
    public function markAllAsRead(User $user): array
    {
        $updatedCount = $user->notifications()
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return [
            'success' => true,
            'data' => ['marked_count' => $updatedCount],
            'message' => 'Semua notifikasi ditandai sebagai sudah dibaca.',
        ];
    }
}
