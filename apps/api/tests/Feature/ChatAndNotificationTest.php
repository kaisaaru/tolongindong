<?php

namespace Tests\Feature;

use App\Enums\HelperAvailability;
use App\Enums\NotificationType;
use App\Enums\OrderStatus;
use App\Models\Address;
use App\Models\ChatMessage;
use App\Models\ChatRoom;
use App\Models\HelperProfile;
use App\Models\Notification;
use App\Models\Order;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Support\Str;
use Tests\TestCase;

class ChatAndNotificationTest extends TestCase
{
    private function createClient(): User
    {
        $unique = Str::random(6);
        return User::create([
            'full_name' => 'Client Chat Tester ' . $unique,
            'email' => "client_chat_{$unique}@example.com",
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);
    }

    private function createHelper(): array
    {
        $unique = Str::random(6);
        $user = User::create([
            'full_name' => 'Helper Chat Tester ' . $unique,
            'email' => "helper_chat_{$unique}@example.com",
            'phone_number' => '0813' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);

        $profile = HelperProfile::create([
            'user_id' => $user->id,
            'hourly_rate' => 20000,
            'max_advance_limit' => 50000,
            'is_available' => HelperAvailability::AVAILABLE,
            'rating_average' => 4.5,
            'rating_count' => 5,
            'completed_order_count' => 3,
            'approved_at' => now(),
        ]);

        return [$user, $profile];
    }

    /**
     * Test DEC-14 no 10 & FR-CHT-001: Chat belum aktif sebelum pesanan berstatus accepted.
     */
    public function test_chat_not_available_before_order_accepted(): void
    {
        $client = $this->createClient();
        $cat = ServiceCategory::first();

        // Pesanan masih searching (mencari helper)
        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::SEARCHING,
            'task_description' => 'Pesanan belum ada helper',
            'total_amount' => 25000,
        ]);

        $response = $this->actingAs($client, 'sanctum')
            ->getJson("/orders/{$order->id}/messages");

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'CHAT_NOT_AVAILABLE');
    }

    /**
     * Test FR-CHT-001, FR-CHT-002: Client dan Helper dapat saling berkirim pesan saat pesanan accepted.
     */
    public function test_client_and_helper_can_exchange_messages_when_accepted(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $cat = ServiceCategory::first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::ACCEPTED,
            'task_description' => 'Pesanan aktif',
            'total_amount' => 30000,
        ]);

        // 1. Client kirim pesan pertama (FR-CHT-001)
        $sendRes = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/messages", [
                'content' => 'Halo mas, posisi di mana?',
            ]);

        $sendRes->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.content', 'Halo mas, posisi di mana?');

        // Notifikasi terkirim ke helper
        $this->assertDatabaseHas('notifications', [
            'user_id' => $helperUser->id,
            'type' => NotificationType::CHAT_MESSAGE->value,
            'reference_order_id' => $order->id,
        ]);

        // 2. Helper membuka riwayat pesan (FR-CHT-002)
        $getRes = $this->actingAs($helperUser, 'sanctum')
            ->getJson("/orders/{$order->id}/messages");

        $getRes->assertStatus(200)
            ->assertJsonPath('success', true);

        $messages = $getRes->json('data.messages');
        $this->assertCount(1, $messages);
        $this->assertNotNull($messages[0]['read_at']); // Pesan terbaca otomatis

        // 3. Helper membalas pesan
        $replyRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$order->id}/messages", [
                'content' => 'Halo kak, saya sedang jalan ke lokasi penjemputan.',
            ]);

        $replyRes->assertStatus(201);

        // Notifikasi balasan terkirim ke client
        $this->assertDatabaseHas('notifications', [
            'user_id' => $client->id,
            'type' => NotificationType::CHAT_MESSAGE->value,
            'reference_order_id' => $order->id,
        ]);
    }

    /**
     * Test pengguna pihak ketiga (bukan client dan bukan helper pesanan) dilarang mengakses chat.
     */
    public function test_non_participant_cannot_access_chat(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $stranger = $this->createClient();
        $cat = ServiceCategory::first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::ACCEPTED,
            'task_description' => 'Pesanan rahasia',
        ]);

        $response = $this->actingAs($stranger, 'sanctum')
            ->getJson("/orders/{$order->id}/messages");

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    /**
     * Test FR-NOT-001 & FR-NOT-005: Pengguna dapat melihat daftar notifikasi dan jumlah unread.
     */
    public function test_user_can_view_notifications_and_unread_count(): void
    {
        $user = $this->createClient();

        NotificationService::createNotification(
            $user->id,
            NotificationType::WALLET_MUTATION,
            'Topup Berhasil',
            'Saldo sebesar Rp 50.000 telah masuk.'
        );

        NotificationService::createNotification(
            $user->id,
            NotificationType::PROMO,
            'Voucher Baru',
            'Gunakan kode HEMAT5K untuk potongan harga.'
        );

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/notifications');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.unread_count', 2);

        $this->assertCount(2, $response->json('data.notifications.data'));
    }

    /**
     * Test menandai satu notifikasi sebagai sudah dibaca.
     */
    public function test_user_can_mark_notification_as_read(): void
    {
        $user = $this->createClient();

        $notif = NotificationService::createNotification(
            $user->id,
            NotificationType::ORDER_STATUS_CHANGE,
            'Helper Tiba',
            'Helper telah tiba di lokasi penjemputan.'
        );

        $this->assertNull($notif->read_at);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/notifications/{$notif->id}/read");

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $this->assertNotNull($notif->fresh()->read_at);
    }

    /**
     * Test menandai semua notifikasi pengguna sebagai sudah dibaca.
     */
    public function test_user_can_mark_all_notifications_as_read(): void
    {
        $user = $this->createClient();

        NotificationService::createNotification($user->id, NotificationType::PROMO, 'Promo 1', 'Diskon 1');
        NotificationService::createNotification($user->id, NotificationType::PROMO, 'Promo 2', 'Diskon 2');

        $this->assertEquals(2, $user->notifications()->whereNull('read_at')->count());

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/notifications/read-all');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $this->assertEquals(0, $user->notifications()->whereNull('read_at')->count());
    }
}
