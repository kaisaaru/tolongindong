<?php

namespace App\Services;

use App\Enums\NotificationType;
use App\Models\ChatMessage;
use App\Models\ChatRoom;
use App\Models\HelperProfile;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ChatService
{
    /**
     * Dapatkan daftar seluruh ruang obrolan milik pengguna (sebagai client maupun helper).
     */
    public function getUserRooms(User $user): array
    {
        $helperProfile = $user->helperProfile;
        $helperId = $helperProfile?->id;

        $rooms = ChatRoom::with(['client', 'helper.user', 'order'])
            ->where(function ($query) use ($user, $helperId) {
                $query->where('client_id', $user->id);
                if ($helperId) {
                    $query->orWhere('helper_id', $helperId);
                }
                $query->orWhereHas('order', function ($q) use ($user, $helperId) {
                    $q->where('client_id', $user->id);
                    if ($helperId) {
                        $q->orWhere('helper_id', $helperId);
                    }
                });
            })
            ->latest('updated_at')
            ->get()
            ->map(function ($room) use ($user) {
                $lastMessage = $room->messages()->latest('created_at')->first();
                $unreadCount = $room->messages()
                    ->where('sender_user_id', '!=', $user->id)
                    ->whereNull('read_at')
                    ->count();

                $isClient = $room->client_id === $user->id || ($room->order && $room->order->client_id === $user->id);
                $peer = $isClient
                    ? ($room->helper?->user ?? $room->order?->helper?->user)
                    : ($room->client ?? $room->order?->client);

                return [
                    'id' => $room->id,
                    'order_id' => $room->order_id,
                    'is_read_only' => $room->is_read_only,
                    'peer' => $peer ? [
                        'id' => $peer->id,
                        'full_name' => $peer->full_name,
                        'photo_url' => $peer->photo_url,
                        'role' => $isClient ? 'helper' : 'client',
                    ] : null,
                    'last_message' => $lastMessage ? [
                        'content' => $lastMessage->content,
                        'created_at' => $lastMessage->created_at,
                        'sender_id' => $lastMessage->sender_user_id,
                    ] : null,
                    'unread_count' => $unreadCount,
                    'updated_at' => $room->updated_at,
                ];
            });

        return [
            'success' => true,
            'data' => $rooms,
            'message' => 'Daftar ruang obrolan berhasil dimuat.',
        ];
    }

    /**
     * Dapatkan atau buat ruang obrolan langsung dengan helper (Pre-Order Chat).
     */
    public function getOrCreateRoomWithHelper(User $client, string $helperProfileId): array
    {
        $helper = HelperProfile::with('user')->find($helperProfileId);

        if (!$helper) {
            return [
                'success' => false,
                'error_code' => 'HELPER_NOT_FOUND',
                'message' => 'Profil helper tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if ($helper->user_id === $client->id) {
            return [
                'success' => false,
                'error_code' => 'CANNOT_CHAT_SELF',
                'message' => 'Anda tidak dapat memulai percakapan dengan akun Anda sendiri.',
                'status_code' => 422,
            ];
        }

        $room = ChatRoom::where('client_id', $client->id)
            ->where('helper_id', $helper->id)
            ->first();

        if (!$room) {
            $room = ChatRoom::create([
                'client_id' => $client->id,
                'helper_id' => $helper->id,
                'is_read_only' => false,
            ]);
        }

        return [
            'success' => true,
            'data' => [
                'room_id' => $room->id,
                'client' => [
                    'id' => $client->id,
                    'full_name' => $client->full_name,
                    'photo_url' => $client->photo_url,
                ],
                'helper' => [
                    'id' => $helper->id,
                    'user_id' => $helper->user_id,
                    'full_name' => $helper->user->full_name,
                    'photo_url' => $helper->user->photo_url,
                    'hourly_rate' => $helper->hourly_rate,
                ],
                'is_read_only' => $room->is_read_only,
            ],
            'message' => 'Ruang obrolan siap digunakan.',
        ];
    }

    /**
     * Dapatkan atau buat ruang obrolan pesanan (DEC-14 no 10, FR-CHT-001).
     */
    public function getOrCreateRoom(Order $order): ?ChatRoom
    {
        return ChatRoom::firstOrCreate(
            ['order_id' => $order->id],
            [
                'client_id' => $order->client_id,
                'helper_id' => $order->helper_id,
                'is_read_only' => false,
            ]
        );
    }

    /**
     * Ambil riwayat percakapan berdasarkan ID ruang obrolan.
     */
    public function getRoomMessages(User $user, int $roomId): array
    {
        $room = ChatRoom::with(['client', 'helper.user', 'order'])->find($roomId);

        if (!$room) {
            return [
                'success' => false,
                'error_code' => 'ROOM_NOT_FOUND',
                'message' => 'Ruang obrolan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$this->isParticipant($user, $room)) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Anda tidak memiliki hak akses ke percakapan ini.',
                'status_code' => 403,
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
     * Kirim pesan ke ruang obrolan tertentu.
     */
    public function sendMessageToRoom(User $sender, int $roomId, string $content, ?string $attachmentUrl = null): array
    {
        $room = ChatRoom::with(['client', 'helper.user', 'order'])->find($roomId);

        if (!$room) {
            return [
                'success' => false,
                'error_code' => 'ROOM_NOT_FOUND',
                'message' => 'Ruang obrolan tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if (!$this->isParticipant($sender, $room)) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya pihak yang terlibat dalam percakapan yang dapat mengirim pesan.',
                'status_code' => 403,
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

        return DB::transaction(function () use ($room, $sender, $content, $attachmentUrl) {
            $msg = ChatMessage::create([
                'chat_room_id' => $room->id,
                'sender_user_id' => $sender->id,
                'content' => $content,
                'attachment_url' => $attachmentUrl,
            ]);

            $room->touch();

            // Tentukan penerima notifikasi
            $isClient = $room->client_id === $sender->id || ($room->order && $room->order->client_id === $sender->id);
            $recipientId = $isClient
                ? ($room->helper?->user_id ?? $room->order?->helper?->user_id)
                : ($room->client_id ?? $room->order?->client_id);

            if ($recipientId) {
                NotificationService::createNotification(
                    $recipientId,
                    NotificationType::CHAT_MESSAGE,
                    "Pesan Baru dari {$sender->full_name}",
                    Str::limit($content, 80),
                    $room->order_id
                );
            }

            return [
                'success' => true,
                'data' => $msg->load('senderUser'),
                'message' => 'Pesan berhasil dikirim.',
                'status_code' => 201,
            ];
        });
    }

    /**
     * Ambil riwayat percakapan antara client dan helper berdasarkan ID pesanan (kompatibilitas lama).
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

        return $this->getRoomMessages($user, $room->id);
    }

    /**
     * Kirim pesan teks atau berkas lampiran berdasarkan ID pesanan (kompatibilitas lama).
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

        $room = $this->getOrCreateRoom($order);

        return $this->sendMessageToRoom($sender, $room->id, $content, $attachmentUrl);
    }

    /**
     * Cek apakah user adalah partisipan sah dalam ruang obrolan.
     */
    protected function isParticipant(User $user, ChatRoom $room): bool
    {
        if ($user->is_admin) {
            return true;
        }

        if ($room->client_id === $user->id) {
            return true;
        }

        if ($room->helper && $room->helper->user_id === $user->id) {
            return true;
        }

        if ($room->order) {
            if ($room->order->client_id === $user->id) {
                return true;
            }
            if ($room->order->helper && $room->order->helper->user_id === $user->id) {
                return true;
            }
        }

        return false;
    }
}
