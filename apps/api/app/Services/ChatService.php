<?php

namespace App\Services;

use App\Enums\NotificationType;
use App\Models\ChatMessage;
use App\Models\ChatRoom;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ChatService
{
    /**
     * Dapatkan atau buat ruang obrolan pesanan (DEC-14 no 10, FR-CHT-001).
     */
    public function getOrCreateRoom(Order $order): ?ChatRoom
    {
        // Ruang chat hanya dibuka saat pesanan accepted atau sedang berjalan (DEC-14 no 10)
        if (!$order->isActive() && $order->status->value !== 'completed') {
            return null;
        }

        return ChatRoom::firstOrCreate(
            ['order_id' => $order->id],
            ['is_read_only' => false]
        );
    }

    /**
     * Ambil riwayat percakapan antara client dan helper (FR-CHT-002).
     */
    public function getMessages(User $user, int $orderId): array
    {
        $order = Order::with(['client', 'helper.user'])->find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        $isClient = $order->client_id === $user->id;
        $isHelper = $order->helper && $order->helper->user_id === $user->id;

        if (!$isClient && !$isHelper && !$user->is_admin) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda tidak memiliki hak akses ke percakapan pesanan ini.',
                'status_code' => 403,
            ];
        }

        $room = $this->getOrCreateRoom($order);

        if (!$room) {
            return [
                'success' => false,
                'error_code' => 'CHAT_NOT_AVAILABLE',
                'message' => 'Ruang obrolan belum tersedia sebelum pesanan diterima oleh helper.',
                'status_code' => 422,
            ];
        }

        // Tandai pesan dari lawan bicara sebagai sudah dibaca
        $room->messages()
            ->where('sender_user_id', '!=', $user->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        $messages = $room->messages()
            ->with('senderUser')
            ->oldest('created_at')
            ->get();

        return [
            'success' => true,
            'data' => [
                'chat_room' => $room,
                'messages' => $messages,
            ],
            'message' => 'Riwayat obrolan berhasil dimuat.',
        ];
    }

    /**
     * Kirim pesan teks atau berkas lampiran (FR-CHT-001).
     */
    public function sendMessage(User $sender, int $orderId, string $content, ?string $attachmentUrl = null): array
    {
        $order = Order::with(['client', 'helper.user'])->find($orderId);

        if (!$order) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Pesanan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        $isClient = $order->client_id === $sender->id;
        $isHelper = $order->helper && $order->helper->user_id === $sender->id;

        if (!$isClient && !$isHelper) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya pihak yang terlibat dalam pesanan yang dapat mengirim pesan.',
                'status_code' => 403,
            ];
        }

        $room = $this->getOrCreateRoom($order);

        if (!$room) {
            return [
                'success' => false,
                'error_code' => 'CHAT_NOT_AVAILABLE',
                'message' => 'Ruang obrolan belum aktif.',
                'status_code' => 422,
            ];
        }

        if ($room->is_read_only) {
            return [
                'success' => false,
                'error_code' => 'CHAT_ROOM_CLOSED',
                'message' => 'Ruang obrolan telah ditutup dan bersifat hanya-baca.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($room, $sender, $content, $attachmentUrl, $order, $isClient) {
            $msg = ChatMessage::create([
                'chat_room_id' => $room->id,
                'sender_user_id' => $sender->id,
                'content' => $content,
                'attachment_url' => $attachmentUrl,
            ]);

            // Kirim notifikasi chat ke lawan bicara
            $recipientId = $isClient ? $order->helper->user_id : $order->client_id;
            NotificationService::createNotification(
                $recipientId,
                NotificationType::CHAT_MESSAGE,
                "Pesan Baru dari {$sender->full_name}",
                Str::limit($content, 80),
                $order->id
            );

            return [
                'success' => true,
                'data' => $msg->load('senderUser'),
                'message' => 'Pesan berhasil dikirim.',
                'status_code' => 201,
            ];
        });
    }
}
