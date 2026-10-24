<?php

namespace Tests\Feature;

use App\Enums\AdminActionType;
use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminOperationsTest extends TestCase
{
    private function createAdmin(): User
    {
        $unique = Str::random(6);
        return User::create([
            'full_name' => 'Admin Op Tester ' . $unique,
            'email' => "admin_op_{$unique}@example.com",
            'phone_number' => '0811' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'is_admin' => true,
        ]);
    }

    private function createClient(int $initialBalance = 100000): User
    {
        $unique = Str::random(6);
        $user = User::create([
            'full_name' => 'Client Op Tester ' . $unique,
            'email' => "client_op_{$unique}@example.com",
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

    /**
     * Test API-ADM-08 & FR-ADM-009: Admin dapat membekukan akun pengguna tanpa pesanan aktif.
     */
    public function test_admin_can_suspend_user_without_active_orders(): void
    {
        $admin = $this->createAdmin();
        $targetUser = $this->createClient();

        // Buat token login untuk user target
        $targetUser->createToken('test_token');
        $this->assertCount(1, $targetUser->tokens);

        $reason = 'Terindikasi melakukan kecurangan dan transaksi palsu.';
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/users/{$targetUser->id}/suspend", [
                'reason' => $reason,
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.is_suspended', true)
            ->assertJsonPath('data.suspended_reason', $reason);

        // Verifikasi token dicabut (DEC-14 no 12)
        $this->assertCount(0, $targetUser->fresh()->tokens);

        // Verifikasi tercatat di admin_action_logs (FR-ADM-008)
        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::SUSPEND_ACCOUNT->value,
            'target_entity' => 'users',
            'target_id' => (string) $targetUser->id,
            'note' => $reason,
        ]);
    }

    /**
     * Test DEC-22: Suspend ditolak jika pengguna masih memiliki pesanan aktif berjalan.
     */
    public function test_admin_cannot_suspend_user_with_active_orders(): void
    {
        $admin = $this->createAdmin();
        $targetUser = $this->createClient();
        $cat = ServiceCategory::first();

        // Pengguna memiliki pesanan aktif in_progress
        Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $targetUser->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::IN_PROGRESS,
            'task_description' => 'Pesanan aktif sedang dikerjakan',
            'total_amount' => 30000,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/users/{$targetUser->id}/suspend", [
                'reason' => 'Mau suspend padahal order masih jalan',
            ]);

        $response->assertStatus(409)
            ->assertJsonPath('error.code', 'ACTIVE_ORDERS_EXIST');

        $this->assertFalse($targetUser->fresh()->is_suspended);
    }

    /**
     * Test API-ADM-09 & FR-ADM-010: Admin dapat mengaktifkan kembali akun yang di-suspend.
     */
    public function test_admin_can_reactivate_suspended_user(): void
    {
        $admin = $this->createAdmin();
        $targetUser = $this->createClient();

        $targetUser->update([
            'is_suspended' => true,
            'suspended_reason' => 'Dibekukan sebelumnya',
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/users/{$targetUser->id}/reactivate");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.is_suspended', false);

        $this->assertFalse($targetUser->fresh()->is_suspended);
        $this->assertNull($targetUser->fresh()->suspended_reason);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::REACTIVATE_ACCOUNT->value,
            'target_entity' => 'users',
            'target_id' => (string) $targetUser->id,
        ]);
    }

    /**
     * Test API-ADM-10, FR-ADM-011 & DEC-22: Admin membatalkan pesanan darurat (dana jasa kembali penuh ke client, helper kompensasi 0).
     */
    public function test_admin_can_cancel_active_order_with_full_client_refund(): void
    {
        $admin = $this->createAdmin();
        $client = $this->createClient(0);
        $cat = ServiceCategory::first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::ACCEPTED,
            'task_description' => 'Pesanan bermasalah mau dibatalkan admin',
            'total_amount' => 45000,
            'service_client_charge' => 45000,
            'held_amount' => 45000,
            'advance_actual' => 0,
        ]);

        $clientWallet = $client->wallet;
        $clientWallet->held_balance = 45000;
        $clientWallet->save();

        $reason = 'Helper tidak dapat dihubungi dan melanggar ketentuan operasional.';
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/orders/{$order->id}/cancel", [
                'reason' => $reason,
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.order.status', OrderStatus::CANCELLED_BY_ADMIN->value)
            ->assertJsonPath('data.client_refund', 45000);

        // Dana kembali utuh ke saldo client (FR-ADM-011)
        $this->assertEquals(45000, $clientWallet->fresh()->available_balance);
        $this->assertEquals(0, $clientWallet->fresh()->held_balance);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::CANCEL_ORDER->value,
            'target_entity' => 'orders',
            'target_id' => (string) $order->id,
            'note' => $reason,
        ]);
    }

    /**
     * Test DEC-22: Pesanan berstatus disputed tidak dapat dibatalkan admin via endpoint cancel (wajib lewat resolve dispute).
     */
    public function test_admin_cannot_cancel_disputed_order_via_cancel_endpoint(): void
    {
        $admin = $this->createAdmin();
        $client = $this->createClient();
        $cat = ServiceCategory::first();

        $order = Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::DISPUTED,
            'task_description' => 'Order disputed',
            'total_amount' => 40000,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/orders/{$order->id}/cancel", [
                'reason' => 'Mau cancel order disputed',
            ]);

        $response->assertStatus(409)
            ->assertJsonPath('error.code', 'ORDER_IN_DISPUTE');
    }

    /**
     * Test API-ADM-07 & FR-ADM-007: Ringkasan pendapatan komisi platform.
     */
    public function test_admin_can_get_platform_commission_summary(): void
    {
        $admin = $this->createAdmin();
        $client = $this->createClient();
        $cat = ServiceCategory::where('code', 'delivery')->first();

        // Pesanan completed dengan komisi platform 5.000
        Order::create([
            'order_number' => 'ORD-' . Str::random(10),
            'client_id' => $client->id,
            'category_id' => $cat->id,
            'booking_type' => 'broadcast',
            'status' => OrderStatus::COMPLETED,
            'task_description' => 'Order completed',
            'total_amount' => 50000,
            'platform_commission' => 5000,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/admin/commission-summary');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'success',
                'data' => [
                    'total_commission',
                    'completed_orders_count',
                    'total_transaction_volume',
                    'category_breakdown',
                ],
            ]);

        $this->assertGreaterThanOrEqual(5000, $response->json('data.total_commission'));
        $this->assertGreaterThanOrEqual(1, $response->json('data.completed_orders_count'));
    }
}
