<?php

namespace Tests\Feature;

use App\Enums\DisputeResolution;
use App\Enums\HelperAvailability;
use App\Enums\OrderStatus;
use App\Enums\PriceAdjustmentStatus;
use App\Models\Address;
use App\Models\Dispute;
use App\Models\HelperProfile;
use App\Models\Order;
use App\Models\PriceAdjustment;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Support\Str;
use Tests\TestCase;

class OrderAdvancedFeaturesTest extends TestCase
{
    private function createClient(int $initialBalance = 100000): User
    {
        $unique = Str::random(6);
        $user = User::create([
            'full_name' => 'Client Adv Tester ' . $unique,
            'email' => "client_adv_{$unique}@example.com",
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
            'full_name' => 'Helper Adv Tester ' . $unique,
            'email' => "helper_adv_{$unique}@example.com",
            'phone_number' => '0813' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);

        $profile = HelperProfile::create([
            'user_id' => $user->id,
            'hourly_rate' => 20000,
            'max_advance_limit' => $maxAdvance,
            'is_available' => HelperAvailability::AVAILABLE,
            'rating_average' => 4.0,
            'rating_count' => 1,
            'completed_order_count' => 5,
            'approved_at' => now(),
        ]);

        Wallet::create([
            'user_id' => $user->id,
            'available_balance' => 0,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);

        return [$user, $profile];
    }

    private function createAdmin(): User
    {
        $unique = Str::random(6);
        return User::create([
            'full_name' => 'Admin Adv Tester ' . $unique,
            'email' => "admin_adv_{$unique}@example.com",
            'phone_number' => '0811' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'is_admin' => true,
        ]);
    }

    /**
     * Test FR-ORD-014: Struk yang nilainya dalam batas talangan langsung auto-approved.
     */
    public function test_receipt_within_advance_limit_is_auto_approved(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $cat = ServiceCategory::where('code', 'food_run')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::IN_PROGRESS,
            'task_description' => 'Beli sate',
            'advance_limit' => 50000,
            'advance_actual' => 0,
            'held_amount' => 70000,
        ]);

        // Helper upload struk Rp 35.000 (masih dalam batas 50k)
        $response = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$order->id}/adjustments", [
                'requested_amount' => 35000,
                'receipt_url' => 'https://r2.tolongindong.id/receipts/struk1.jpg',
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.adjustment.approval_status', PriceAdjustmentStatus::AUTO_APPROVED->value)
            ->assertJsonPath('data.adjustment.recognized_amount', 35000);

        $this->assertEquals(35000, $order->fresh()->advance_actual);
        $this->assertEquals(OrderStatus::IN_PROGRESS, $order->fresh()->status);
    }

    /**
     * Test FR-ORD-014: Struk melebihi batas talangan mengubah status ke price_adjustment & pending.
     */
    public function test_receipt_exceeding_advance_limit_requires_client_approval(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $cat = ServiceCategory::where('code', 'food_run')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::IN_PROGRESS,
            'task_description' => 'Beli martabak spesial',
            'advance_limit' => 50000,
            'advance_actual' => 0,
            'held_amount' => 70000,
        ]);

        // Helper upload struk Rp 65.000 (melebihi batas 50k)
        $response = $this->actingAs($helperUser, 'sanctum')
            ->postJson("/orders/{$order->id}/adjustments", [
                'requested_amount' => 65000,
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.adjustment.approval_status', PriceAdjustmentStatus::PENDING->value)
            ->assertJsonPath('data.order.status', OrderStatus::PRICE_ADJUSTMENT->value);

        $this->assertEquals(OrderStatus::PRICE_ADJUSTMENT, $order->fresh()->status);
    }

    /**
     * Test DEC-20 & Turunan SA #2: Client menyetujui penyesuaian belanja -> saldo tambahan ditahan.
     */
    public function test_client_approves_adjustment_holds_additional_escrow(): void
    {
        $client = $this->createClient(100000); // 100k tersedia
        [$helperUser, $helperProfile] = $this->createHelper();
        $cat = ServiceCategory::where('code', 'food_run')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::PRICE_ADJUSTMENT,
            'task_description' => 'Beli seafood',
            'advance_limit' => 50000,
            'advance_actual' => 0,
            'held_amount' => 70000,
        ]);

        $adj = PriceAdjustment::create([
            'order_id' => $order->id,
            'requested_amount' => 65000,
            'approval_status' => PriceAdjustmentStatus::PENDING,
        ]);

        // Client setuju -> kelebihan Rp 15.000 ditahan
        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/adjustments/{$adj->id}/respond", [
                'action' => 'approved',
            ]);

        $response->assertStatus(200);

        $adj->refresh();
        $this->assertEquals(PriceAdjustmentStatus::APPROVED, $adj->approval_status);
        $this->assertEquals(65000, $adj->recognized_amount);
        $this->assertEquals(15000, $adj->additional_hold_amount);

        // Held amount naik jadi 70k + 15k = 85k
        $this->assertEquals(85000, $order->fresh()->held_amount);
        $this->assertEquals(OrderStatus::IN_PROGRESS, $order->fresh()->status);
    }

    /**
     * Test DEC-20: Client menolak penyesuaian belanja -> diakui hanya sisa limit lama, kelebihan jadi risiko helper.
     */
    public function test_client_rejects_adjustment_caps_at_original_limit(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $cat = ServiceCategory::where('code', 'food_run')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::PRICE_ADJUSTMENT,
            'task_description' => 'Beli bebek',
            'advance_limit' => 50000,
            'advance_actual' => 0,
            'held_amount' => 70000,
        ]);

        $adj = PriceAdjustment::create([
            'order_id' => $order->id,
            'requested_amount' => 65000,
            'approval_status' => PriceAdjustmentStatus::PENDING,
        ]);

        // Client menolak
        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/adjustments/{$adj->id}/respond", [
                'action' => 'rejected',
            ]);

        $response->assertStatus(200);

        $adj->refresh();
        $this->assertEquals(PriceAdjustmentStatus::REJECTED, $adj->approval_status);
        $this->assertEquals(50000, $adj->recognized_amount); // hanya diakui 50k
        $this->assertEquals(0, $adj->additional_hold_amount);
        $this->assertEquals(50000, $order->fresh()->advance_actual);
        $this->assertEquals(OrderStatus::IN_PROGRESS, $order->fresh()->status);
    }

    /**
     * Test FR-ORD-018 & DEC-10: Sengketa Delivery dapat diajukan.
     */
    public function test_delivery_order_can_be_disputed(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $deliveryCat = ServiceCategory::where('code', 'delivery')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $deliveryCat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::AWAITING_CONFIRMATION,
            'task_description' => 'Antar paket dokumen penting',
            'total_amount' => 30000,
            'held_amount' => 30000,
        ]);

        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/disputes", [
                'reason' => 'Barang basah kuyup terkena hujan dan sobek',
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.order.status', OrderStatus::DISPUTED->value);

        $this->assertEquals(OrderStatus::DISPUTED, $order->fresh()->status);
    }

    /**
     * Test DEC-10 & DEC-20: Sengketa ditolak pada kategori non-Delivery (misal Food Run).
     */
    public function test_non_delivery_order_cannot_be_disputed(): void
    {
        $client = $this->createClient();
        [$helperUser, $helperProfile] = $this->createHelper();
        $foodCat = ServiceCategory::where('code', 'food_run')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $foodCat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::AWAITING_CONFIRMATION,
            'task_description' => 'Beli nasi uduk',
            'total_amount' => 20000,
            'held_amount' => 20000,
        ]);

        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/disputes", [
                'reason' => 'Sambalnya kurang pedas',
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'DISPUTE_NOT_ELIGIBLE');
    }

    /**
     * Test FR-ADM-006: Admin memutuskan sengketa favor_client (refund penuh).
     */
    public function test_admin_resolves_dispute_favor_client(): void
    {
        $admin = $this->createAdmin();
        $client = $this->createClient(0);
        [$helperUser, $helperProfile] = $this->createHelper();
        $deliveryCat = ServiceCategory::where('code', 'delivery')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $deliveryCat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::DISPUTED,
            'task_description' => 'Antar kue tart',
            'total_amount' => 50000,
            'held_amount' => 50000,
        ]);

        $clientWallet = $client->wallet;
        $clientWallet->held_balance = 50000;
        $clientWallet->save();

        $dispute = Dispute::create([
            'order_id' => $order->id,
            'raised_by_user_id' => $client->id,
            'reason' => 'Kue hancur berantakan',
            'resolution' => DisputeResolution::PENDING,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/disputes/{$dispute->id}/resolve", [
                'resolution' => 'favor_client',
                'admin_note' => 'Bukti foto jelas kue hancur total karena kelalaian kurir.',
            ]);

        $response->assertStatus(200);

        $order->refresh();
        $this->assertEquals(OrderStatus::REFUNDED, $order->status);
        $this->assertEquals(50000, $clientWallet->fresh()->available_balance); // Refund penuh ke client
        $this->assertEquals(0, $clientWallet->fresh()->held_balance);
    }

    /**
     * Test FR-ADM-006 & Turunan SA #4, #8: Admin memutuskan sengketa split 50:50.
     */
    public function test_admin_resolves_dispute_split_50_50(): void
    {
        $admin = $this->createAdmin();
        $client = $this->createClient(0);
        [$helperUser, $helperProfile] = $this->createHelper();
        $deliveryCat = ServiceCategory::where('code', 'delivery')->first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'helper_id' => $helperProfile->id,
            'category_id' => $deliveryCat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::DISPUTED,
            'task_description' => 'Antar barang pecah belah',
            'total_amount' => 50000,
            'held_amount' => 50000,
        ]);

        $clientWallet = $client->wallet;
        $clientWallet->held_balance = 50000;
        $clientWallet->save();

        $dispute = Dispute::create([
            'order_id' => $order->id,
            'raised_by_user_id' => $client->id,
            'reason' => 'Kardus penyok sedikit',
            'resolution' => DisputeResolution::PENDING,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/disputes/{$dispute->id}/resolve", [
                'resolution' => 'split',
                'admin_note' => 'Kedua pihak sepakat bagi risiko sama rata.',
            ]);

        $response->assertStatus(200);

        $order->refresh();
        $this->assertEquals(OrderStatus::PARTIALLY_REFUNDED, $order->status); // Turunan SA #4
        $this->assertEquals(25000, $clientWallet->fresh()->available_balance); // 50:50
        $this->assertEquals(25000, $helperUser->wallet->fresh()->available_balance); // 50:50
    }

    /**
     * Test FR-RTG-001 & DEC-09: Client memberi rating ke helper pada order completed & rating helper ter-update.
     */
    public function test_client_can_rate_completed_order_and_updates_helper_rating(): void
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
            'status' => OrderStatus::COMPLETED,
            'task_description' => 'Pekerjaan beres',
            'total_amount' => 20000,
        ]);

        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/rating", [
                'score' => 5,
                'review' => 'Pelayanan ramah, cepat, dan sangat rapi!',
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.score', 5);

        // Helper profile rating ter-recalculate
        $helperProfile->refresh();
        $this->assertEquals(1, $helperProfile->rating_count);
        $this->assertEquals(5.0, (float) $helperProfile->rating_average);
    }

    /**
     * Test FR-RTG-004: Rating ditolak jika pesanan berstatus batal.
     */
    public function test_rating_rejected_on_cancelled_order(): void
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
            'status' => OrderStatus::CANCELLED_BY_CLIENT,
            'task_description' => 'Pesanan dibatalkan',
        ]);

        $response = $this->actingAs($client, 'sanctum')
            ->postJson("/orders/{$order->id}/rating", [
                'score' => 1,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'ORDER_NOT_COMPLETED');
    }
}
