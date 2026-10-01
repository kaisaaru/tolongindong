<?php

namespace Tests\Feature;

use App\Enums\AdminActionType;
use App\Enums\DiscountType;
use App\Models\User;
use App\Models\Voucher;
use Illuminate\Support\Str;
use Tests\TestCase;

class VoucherApiTest extends TestCase
{
    private function createAdmin(): User
    {
        $unique = Str::random(6);
        return User::create([
            'full_name' => 'Admin Voucher Tester ' . $unique,
            'email' => "admin_vc_{$unique}@example.com",
            'phone_number' => '0811' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'is_admin' => true,
        ]);
    }

    private function createClient(): User
    {
        $unique = Str::random(6);
        return User::create([
            'full_name' => 'Client Voucher Tester ' . $unique,
            'email' => "client_vc_{$unique}@example.com",
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);
    }

    /**
     * Test API-ADM-12 & DEC-23: Admin membuat voucher nominal tetap valid (min_order >= 10x diskon).
     */
    public function test_admin_can_create_valid_fixed_voucher(): void
    {
        $admin = $this->createAdmin();
        $code = 'HEMAT' . strtoupper(Str::random(5));

        // Diskon 5.000 dengan min order 50.000 (tepat 10x)
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/admin/vouchers', [
                'code' => $code,
                'discount_type' => 'fixed',
                'discount_value' => 5000,
                'min_order_amount' => 50000,
                'usage_limit' => 50,
                'valid_from' => now()->toIso8601String(),
                'valid_until' => now()->addDays(30)->toIso8601String(),
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.code', $code)
            ->assertJsonPath('data.discount_value', 5000);

        $this->assertDatabaseHas('vouchers', [
            'code' => $code,
            'discount_type' => DiscountType::FIXED->value,
            'discount_value' => 5000,
        ]);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::CREATE_VOUCHER->value,
            'target_entity' => 'vouchers',
        ]);
    }

    /**
     * Test DEC-23 & T-11: Voucher nominal tetap ditolak jika min_order kurang dari 10x nilai diskon.
     */
    public function test_admin_fixed_voucher_rejected_if_min_order_below_10x_discount(): void
    {
        $admin = $this->createAdmin();

        // Diskon 5.000 tapi min order cuma 45.000 (< 50.000)
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/admin/vouchers', [
                'code' => 'RUGI' . strtoupper(Str::random(5)),
                'discount_type' => 'fixed',
                'discount_value' => 5000,
                'min_order_amount' => 45000,
                'valid_from' => now()->toIso8601String(),
                'valid_until' => now()->addDays(30)->toIso8601String(),
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VOUCHER_EXCEEDS_COMMISSION');
    }

    /**
     * Test DEC-23 & FR-WLT-013: Voucher persentase ditolak jika melebihi 10%.
     */
    public function test_admin_percentage_voucher_rejected_above_10_percent(): void
    {
        $admin = $this->createAdmin();

        // Diskon 15% (melebihi batas komisi 10%)
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/admin/vouchers', [
                'code' => 'DISC15' . strtoupper(Str::random(4)),
                'discount_type' => 'percentage',
                'discount_value' => 15,
                'min_order_amount' => 20000,
                'valid_from' => now()->toIso8601String(),
                'valid_until' => now()->addDays(30)->toIso8601String(),
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VOUCHER_EXCEEDS_COMMISSION');
    }

    /**
     * Test DEC-23: Voucher persentase berhasil jika <= 10%.
     */
    public function test_admin_can_create_valid_percentage_voucher(): void
    {
        $admin = $this->createAdmin();
        $code = 'DISC10' . strtoupper(Str::random(4));

        $response = $this->actingAs($admin, 'sanctum')
            ->postJson('/admin/vouchers', [
                'code' => $code,
                'discount_type' => 'percentage',
                'discount_value' => 10,
                'min_order_amount' => 30000,
                'valid_from' => now()->toIso8601String(),
                'valid_until' => now()->addDays(30)->toIso8601String(),
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.discount_value', 10);
    }

    /**
     * Test API-ADM-13: Admin dapat mengubah dan menonaktifkan voucher.
     */
    public function test_admin_can_update_and_deactivate_voucher(): void
    {
        $admin = $this->createAdmin();

        $voucher = Voucher::create([
            'code' => 'PROMO' . strtoupper(Str::random(5)),
            'discount_type' => DiscountType::FIXED,
            'discount_value' => 3000,
            'min_order_amount' => 30000,
            'is_active' => true,
            'valid_from' => now(),
            'valid_until' => now()->addDays(10),
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->patchJson("/admin/vouchers/{$voucher->id}", [
                'is_active' => false,
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.is_active', false);

        $this->assertFalse($voucher->fresh()->is_active);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::DEACTIVATE_VOUCHER->value,
            'target_entity' => 'vouchers',
            'target_id' => (string) $voucher->id,
        ]);
    }

    /**
     * Test FR-WLT-010: Client mengklaim voucher dan melihat daftar voucher miliknya.
     */
    public function test_client_can_claim_voucher_and_list_active_vouchers(): void
    {
        $client = $this->createClient();
        $code = 'KLAIM' . strtoupper(Str::random(5));

        $voucher = Voucher::create([
            'code' => $code,
            'discount_type' => DiscountType::FIXED,
            'discount_value' => 5000,
            'min_order_amount' => 50000,
            'is_active' => true,
            'valid_from' => now()->subDay(),
            'valid_until' => now()->addDays(20),
        ]);

        // 1. Klaim pertama
        $claimRes = $this->actingAs($client, 'sanctum')
            ->postJson('/vouchers/claim', [
                'code' => $code,
            ]);

        $claimRes->assertStatus(201)
            ->assertJsonPath('success', true);

        // 2. Klaim kedua ditolak (duplikasi)
        $claimAgain = $this->actingAs($client, 'sanctum')
            ->postJson('/vouchers/claim', [
                'code' => $code,
            ]);

        $claimAgain->assertStatus(422)
            ->assertJsonPath('error.code', 'VOUCHER_ALREADY_CLAIMED');

        // 3. Tampilkan daftar voucher client
        $listRes = $this->actingAs($client, 'sanctum')
            ->getJson('/vouchers');

        $listRes->assertStatus(200)
            ->assertJsonPath('success', true);

        $codes = collect($listRes->json('data'))->pluck('code')->all();
        $this->assertContains($code, $codes);
    }
}
