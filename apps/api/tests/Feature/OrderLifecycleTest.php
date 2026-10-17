<?php

namespace Tests\Feature;

use App\Enums\HelperAvailability;
use App\Enums\OrderStatus;
use App\Models\Address;
use App\Models\HelperProfile;
use App\Models\Order;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrderLifecycleTest extends TestCase
{
    private function createClient(int $initialBalance = 100000): User
    {
        $unique = Str::random(6);
        $user = User::create([
            'full_name' => 'Client Order Tester ' . $unique,
            'email' => "client_ord_{$unique}@example.com",
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);

        Wallet::create([
            'user_id' => $user->id,
            'available_balance' => $initialBalance,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);

        return $user;
    }

    private function createHelper(int $maxAdvance = 100000): array
    {
        $unique = Str::random(6);
        $user = User::create([
            'full_name' => 'Helper Order Tester ' . $unique,
            'email' => "helper_ord_{$unique}@example.com",
            'phone_number' => '0813' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);

        $profile = HelperProfile::create([
            'user_id' => $user->id,
            'hourly_rate' => 20000,
            'max_advance_limit' => $maxAdvance,
            'is_available' => HelperAvailability::AVAILABLE,
            'rating_average' => 4.8,
            'rating_count' => 12,
            'completed_order_count' => 10,
            'approved_at' => now(),
        ]);

        $address = Address::create([
            'user_id' => $user->id,
            'label' => 'Basecamp Helper',
            'full_address' => 'Jl. Basecamp No. 1',
            'latitude' => -7.755,
            'longitude' => 110.375,
            'is_primary' => true,
        ]);

        Wallet::create([
            'user_id' => $user->id,
            'available_balance' => 0,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);

        return [$user, $profile, $address];
    }

    /**
     * Test API-ORD-01 & FR-ORD-002: Estimasi acuan biaya sebelum membuat pesanan.
     */
    public function test_order_cost_estimation_endpoint(): void
    {
        $client = $this->createClient();
        $category = ServiceCategory::where('code', 'delivery')->first();

        $response = $this->actingAs($client, 'sanctum')
            ->postJson('/orders/estimate', [
                'category_id' => $category->id,
                'distance_km' => 4.0, // 4 km x 2.500 = 10.000
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.base_fee', $category->base_fee)
            ->assertJsonPath('data.distance_fee', 10000)
            ->assertJsonPath('data.service_fee', $category->base_fee);
    }

    /**
     * Test End-to-End Siklus Hidup Pesanan Broadcast:
     * create -> submit offer -> select offer -> confirm offer (escrow hold) -> progress -> complete & release.
     */
    public function test_full_broadcast_order_lifecycle(): void
    {
        $client = $this->createClient(100000); // Saldo 100.000
        [$helperUser, $helperProfile] = $this->createHelper(100000);

        $category = ServiceCategory::where('code', 'delivery')->first();

        // 1. Client membuat pesanan broadcast (searching)
        $createRes = $this->actingAs($client, 'sanctum')
            ->postJson('/orders', [
                'category_id' => $category->id,
                'booking_type' => 'broadcast',
                'task_description' => 'Tolong belikan nasi goreng pak dul di jl pandega',
                'advance_limit' => 30000,
                'client_estimated_price' => 20000,
            ]);

        $createRes->assertStatus(201)
            ->assertJsonPath('data.status', OrderStatus::SEARCHING->value);

        $orderId = $createRes->json('data.id');

        // 2. Helper mengajukan penawaran harga Rp 20.000 (API-ORD-04A)
        $offerRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$orderId}/offers", [
                'proposed_price' => 20000,
                'message' => 'Saya sedang dekat warung, siap belikan sekarang.',
            ]);

        $offerRes->assertStatus(201);
        $offerId = $offerRes->json('data.id');

        // 3. Client memilih tawaran helper (API-ORD-04C) -> status pending_confirmation
        $selectRes = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$orderId}/offers/{$offerId}/select");

        $selectRes->assertStatus(200)
            ->assertJsonPath('data.order.status', OrderStatus::PENDING_CONFIRMATION->value);

        // 4. Helper mengonfirmasi dalam 60 detik (API-ORD-04D) -> status ACCEPTED & Escrow Held
        // Total hold = proposed_price (20.000) + advance_limit (30.000) = 50.000
        $confirmRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$orderId}/offers/{$offerId}/confirm");

        $confirmRes->assertStatus(200)
            ->assertJsonPath('data.order.status', OrderStatus::ACCEPTED->value);

        // Verifikasi saldo client ditahan
        $clientWallet = $client->wallet->fresh();
        $this->assertEquals(50000, $clientWallet->available_balance); // 100k - 50k
        $this->assertEquals(50000, $clientWallet->held_balance);

        // 5. Helper memajukan progres status: on_the_way -> arrived -> in_progress -> awaiting_confirmation
        $this->actingAs($helperUser, 'sanctum')->postJson("/orders/{$orderId}/status", ['status' => 'on_the_way'])->assertStatus(200);
        $this->actingAs($helperUser, 'sanctum')->postJson("/orders/{$orderId}/status", ['status' => 'arrived'])->assertStatus(200);
        $this->actingAs($helperUser, 'sanctum')->postJson("/orders/{$orderId}/status", ['status' => 'in_progress'])->assertStatus(200);
        $this->actingAs($helperUser, 'sanctum')->postJson("/orders/{$orderId}/status", ['status' => 'awaiting_confirmation'])->assertStatus(200);

        // 6. Client mengonfirmasi pekerjaan selesai (API-ORD-08) -> status COMPLETED & Escrow Released
        $completeRes = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$orderId}/confirm");

        $completeRes->assertStatus(200)
            ->assertJsonPath('data.order.status', OrderStatus::COMPLETED->value);

        // Verifikasi kalkulasi keuangan:
        // total_amount = 20.000
        // gross commission (10%) = 2.000
        // helper payout bersih = 18.000
        // advance limit tidak terpakai = 30.000 kembali ke client
        $helperWallet = $helperUser->wallet->fresh();
        $this->assertEquals(18000, $helperWallet->available_balance);

        $clientWalletFinal = $client->wallet->fresh();
        $this->assertEquals(80000, $clientWalletFinal->available_balance); // 50k sisa + 30k refund talangan
        $this->assertEquals(0, $clientWalletFinal->held_balance);
    }

    /**
     * Test Direct Booking Order Lifecycle (FR-ORD-003D):
     * direct order -> awaiting_quote -> submit quote -> client select (auto hold & accepted).
     */
    public function test_direct_booking_order_lifecycle(): void
    {
        $client = $this->createClient(100000);
        [$helperUser, $helperProfile] = $this->createHelper(50000);
        $category = ServiceCategory::where('code', 'personal')->first();

        // 1. Client membuat pesanan direct booking ke helper tertentu
        $createRes = $this->actingAs($client, 'sanctum')
            ->postJson('/orders', [
                'category_id' => $category->id,
                'booking_type' => 'direct',
                'helper_id' => $helperProfile->id,
                'task_description' => 'Bantu pindahan lemari kamar',
            ]);

        $createRes->assertStatus(201)
            ->assertJsonPath('data.status', OrderStatus::AWAITING_QUOTE->value);

        $orderId = $createRes->json('data.id');

        // 2. Helper memberikan quote Rp 35.000
        $quoteRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$orderId}/offers", [
                'proposed_price' => 35000,
                'message' => 'Quote jasa angkat pindahan lemari',
            ]);

        $quoteRes->assertStatus(201);
        $offerId = $quoteRes->json('data.id');

        // 3. Client menyetujui quote -> langsung menahan dana dan status ACCEPTED
        $selectRes = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$orderId}/offers/{$offerId}/select");

        $selectRes->assertStatus(200)
            ->assertJsonPath('data.order.status', OrderStatus::ACCEPTED->value);

        // Saldo tertahan Rp 35.000
        $this->assertEquals(35000, $client->wallet->fresh()->held_balance);
    }

    /**
     * Test FR-ORD-016: Helper dilarang mengajukan tawaran pada pesanan miliknya sendiri.
     */
    public function test_helper_cannot_bid_own_order(): void
    {
        [$user, $profile] = $this->createHelper();
        $category = ServiceCategory::first();

        // User membuat pesanan sebagai client
        $order = Order::create([
            'order_number' => 'ORD-TEST-OWN-' . Str::random(8),
            'client_id' => $user->id,
            'category_id' => $category->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::SEARCHING,
            'task_description' => 'Pesanan saya sendiri',
            'client_estimated_price' => 20000,
        ]);

        // User mencoba membid pesanan sendiri
        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/orders/{$order->id}/offers", [
                'proposed_price' => 25000,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'CANNOT_BID_OWN_ORDER');
    }

    /**
     * Test DEC-17 / FR-ORD-020: Helper dengan max_advance_limit < advance_limit pesanan ditolak saat menawar.
     */
    public function test_helper_with_insufficient_advance_limit_rejected(): void
    {
        $client = $this->createClient();
        // Helper punya batas talangan maksimal hanya 20.000
        [$helperUser, $helperProfile] = $this->createHelper(20000);

        $category = ServiceCategory::where('code', 'delivery')->first();
        $category->update(['requires_advance' => true]);

        // Pesanan butuh talangan 50.000
        $order = Order::create([
            'order_number' => 'ORD-TEST-ADV-' . Str::random(8),
            'client_id' => $client->id,
            'category_id' => $category->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::SEARCHING,
            'task_description' => 'Belanja banyak butuh talangan 50k',
            'advance_limit' => 50000,
            'client_estimated_price' => 20000,
        ]);

        $response = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$order->id}/offers", [
                'proposed_price' => 20000,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'INSUFFICIENT_ADVANCE_LIMIT');
    }

    /**
     * Test FR-ORD-011 & DEC-19: Pembatalan oleh client pada status on_the_way dikenakan kompensasi 25% ke helper.
     */
    public function test_client_cancellation_with_compensation(): void
    {
        $client = $this->createClient(100000);
        [$helperUser, $helperProfile] = $this->createHelper();
        $category = ServiceCategory::first();

        // Pesanan aktif dengan total harga 40.000
        $order = Order::create([
            'order_number' => 'ORD-TEST-CANCEL-' . Str::random(8),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $category->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::ON_THE_WAY,
            'task_description' => 'Pesanan mau dibatalkan',
            'total_amount' => 40000,
            'service_client_charge' => 40000,
            'held_amount' => 40000,
        ]);

        // Simulasikan dana 40.000 ditahan
        $clientWallet = $client->wallet;
        $clientWallet->available_balance = 60000;
        $clientWallet->held_balance = 40000;
        $clientWallet->save();

        // Client membatalkan saat helper on_the_way -> denda 25% = 10.000
        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/cancel", [
                'reason' => 'Ada keperluan mendadak',
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.order.status', OrderStatus::CANCELLED_BY_CLIENT->value)
            ->assertJsonPath('data.cancellation.cancellation_fee', 10000)
            ->assertJsonPath('data.cancellation.client_refund', 30000);

        // Helper menerima kompensasi 10.000 utuh tanpa potongan komisi
        $this->assertEquals(10000, $helperUser->wallet->fresh()->available_balance);

        // Client menerima refund 30.000 (dari 40.000 yang ditahan)
        $this->assertEquals(90000, $clientWallet->fresh()->available_balance); // 60k + 30k
        $this->assertEquals(0, $clientWallet->fresh()->held_balance);
    }

    /**
     * Test Marketplace Gojek-style: Helper dapat langsung menerima atau menolak pesanan direct.
     */
    public function test_helper_can_directly_accept_and_reject_marketplace_order(): void
    {
        $client = $this->createClient(100000);
        [$helperUser, $helperProfile] = $this->createHelper();
        $category = ServiceCategory::where('code', 'personal')->first();
        $helperProfile->serviceCategories()->sync([$category->id]);

        // 1. Client membuat pesanan langsung memilih Helper (Marketplace)
        $createRes = $this->actingAs($client, 'sanctum')
            ->postJson('/orders', [
                'category_id' => $category->id,
                'booking_type' => 'direct',
                'helper_id' => $helperProfile->id,
                'task_description' => 'Antar paket dokumen ke kantor',
                'client_estimated_price' => 30000,
            ]);

        $createRes->assertStatus(201);
        $orderId = $createRes->json('data.id');

        // 2. Helper langsung menerima pesanan (Accept)
        $acceptRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$orderId}/accept");

        $acceptRes->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', OrderStatus::ACCEPTED->value);

        // Escrow client otomatis ditahan Rp 30.000
        $this->assertEquals(30000, $client->wallet->fresh()->held_balance);

        // 3. Tes penolakan (Reject) pada pesanan lain
        $createRes2 = $this->actingAs($client, 'sanctum')
            ->postJson('/orders', [
                'category_id' => $category->id,
                'booking_type' => 'direct',
                'helper_id' => $helperProfile->id,
                'task_description' => 'Antar paket kedua',
                'client_estimated_price' => 20000,
            ]);

        $orderId2 = $createRes2->json('data.id');

        $rejectRes = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$orderId2}/reject", [
                'reason' => 'Sedang ada keperluan mendadak',
            ]);

        $rejectRes->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', OrderStatus::CANCELLED_BY_HELPER->value);
    }
}
