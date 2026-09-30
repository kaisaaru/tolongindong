<?php

namespace Tests\Feature;

use App\Enums\AdminActionType;
use App\Models\AdminActionLog;
use App\Models\HelperProfile;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\VerificationRequest;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminAuthAndAccessTest extends TestCase
{
    /**
     * Test FR-ADM-001 / API-ADM-01: Admin berhasil login via /admin/auth/login.
     */
    public function test_admin_can_login_via_admin_auth_endpoint(): void
    {
        $unique = Str::random(6);
        $email = "admin_{$unique}@example.com";
        $password = 'SecretAdmin123!';

        User::create([
            'full_name' => 'Super Administrator',
            'email' => $email,
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => $password,
            'is_admin' => true,
            'verification_status' => 'verified',
        ]);

        $response = $this->postJson('/admin/auth/login', [
            'identifier' => $email,
            'password' => $password,
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.user.email', $email)
            ->assertJsonPath('data.user.is_admin', true)
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'token',
                    'user' => ['id', 'full_name', 'email', 'is_admin'],
                ],
            ]);
    }

    /**
     * Test FR-ADM-001: Pengguna biasa (non-admin) ditolak saat mencoba login di /admin/auth/login.
     */
    public function test_regular_user_cannot_login_via_admin_auth_endpoint(): void
    {
        $unique = Str::random(6);
        $email = "client_{$unique}@example.com";
        $password = 'UserPass123!';

        User::create([
            'full_name' => 'Regular Client',
            'email' => $email,
            'phone_number' => '0813' . rand(10000000, 99999999),
            'password' => $password,
            'is_admin' => false,
        ]);

        $response = $this->postJson('/admin/auth/login', [
            'identifier' => $email,
            'password' => $password,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    /**
     * Test FR-ADM-002: Non-admin ditolak saat mengakses endpoint admin.
     */
    public function test_non_admin_user_is_forbidden_from_admin_endpoints(): void
    {
        $unique = Str::random(6);
        $regularUser = User::create([
            'full_name' => 'Regular Member',
            'email' => "regular_{$unique}@example.com",
            'phone_number' => '0814' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'is_admin' => false,
        ]);

        $response = $this->actingAs($regularUser, 'sanctum')
            ->getJson('/admin/dashboard');

        $response->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    /**
     * Test FR-ADM-008: Tindakan persetujuan dan penolakan admin dicatat ke admin_action_logs.
     */
    public function test_admin_approval_and_rejection_logs_action(): void
    {
        $unique = Str::random(6);
        $admin = User::create([
            'full_name' => 'Audit Admin',
            'email' => "audit_admin_{$unique}@example.com",
            'phone_number' => '0815' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'is_admin' => true,
        ]);

        $helperUser = User::create([
            'full_name' => 'Helper Audit Target',
            'email' => "helper_audit_{$unique}@example.com",
            'phone_number' => '0816' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'pending',
        ]);

        HelperProfile::create([
            'user_id' => $helperUser->id,
            'hourly_rate' => 35000,
            'max_advance_limit' => 100000,
            'is_available' => false,
        ]);

        $ticket = VerificationRequest::create([
            'user_id' => $helperUser->id,
            'id_card_url' => 'https://r2.tolongindong.id/verifications/id.jpg',
            'selfie_url' => 'https://r2.tolongindong.id/verifications/selfie.jpg',
            'review_status' => 'pending',
        ]);

        // 1. Approve
        $approveRes = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/verifications/{$ticket->id}/approve");

        $approveRes->assertStatus(200);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::APPROVE_VERIFICATION->value,
            'target_entity' => 'verification_requests',
            'target_id' => (string) $ticket->id,
        ]);

        // 2. Buat tiket baru untuk uji reject
        $ticketReject = VerificationRequest::create([
            'user_id' => $helperUser->id,
            'id_card_url' => 'https://r2.tolongindong.id/verifications/id2.jpg',
            'selfie_url' => 'https://r2.tolongindong.id/verifications/selfie2.jpg',
            'review_status' => 'pending',
        ]);

        $rejectReason = 'Foto KTP buram dan nomor NIK tidak terbaca.';
        $rejectRes = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/verifications/{$ticketReject->id}/reject", [
                'rejection_reason' => $rejectReason,
            ]);

        $rejectRes->assertStatus(200);

        $this->assertDatabaseHas('admin_action_logs', [
            'admin_user_id' => $admin->id,
            'action_type' => AdminActionType::REJECT_VERIFICATION->value,
            'target_entity' => 'verification_requests',
            'target_id' => (string) $ticketReject->id,
            'note' => $rejectReason,
        ]);
    }

    /**
     * Test Turunan SA #10: Kategori layanan memuat requires_pickup_photo dan is_dispute_eligible.
     */
    public function test_service_categories_includes_pickup_photo_and_dispute_eligible(): void
    {
        $response = $this->getJson('/service-categories');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $categories = collect($response->json('data'));
        $delivery = $categories->firstWhere('code', 'delivery');
        $foodRun = $categories->firstWhere('code', 'food_run');

        $this->assertNotNull($delivery);
        $this->assertTrue($delivery['requires_pickup_photo']);
        $this->assertTrue($delivery['is_dispute_eligible']);

        $this->assertNotNull($foodRun);
        $this->assertFalse($foodRun['requires_pickup_photo']);
        $this->assertFalse($foodRun['is_dispute_eligible']);
    }
}
