<?php

namespace Tests\Feature;

use App\Models\HelperProfile;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\VerificationRequest;
use Database\Seeders\ServiceCategorySeeder;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class HelperRegistrationTest extends TestCase
{
    use DatabaseTransactions;

    protected function setUp(): void
    {
        parent::setUp();
        // Pastikan 6 kategori tersedia
        $this->seed(ServiceCategorySeeder::class);
    }

    /**
     * Test mendapatkan daftar kategori layanan aktif.
     */
    public function test_user_can_fetch_service_categories(): void
    {
        $response = $this->getJson('/service-categories');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonCount(3, 'data')
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    '*' => [
                        'id',
                        'code',
                        'name',
                        'base_fee',
                        'requires_advance',
                        'requires_proof_photo',
                        'requires_pickup_address',
                        'requires_destination_address',
                    ],
                ],
            ]);
    }

    /**
     * Test pendaftaran helper dengan berkas foto e-KTP dan selfie berhasil.
     */
    public function test_user_can_register_as_helper_with_documents(): void
    {
        Storage::fake(config('filesystems.default', 'r2'));

        $user = User::create([
            'full_name' => 'Rian Sanjaya',
            'email' => 'rian_' . time() . '@example.com',
            'phone_number' => '0852' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'unverified',
        ]);

        $categories = ServiceCategory::whereIn('code', ['delivery', 'personal'])->pluck('id')->toArray();

        $payload = [
            'category_ids' => $categories,
            'hourly_rate' => 25000,
            'max_advance_limit' => 150000,
            'id_card_photo' => UploadedFile::fake()->create('ktp.jpg', 100, 'image/jpeg'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 100, 'image/jpeg'),
        ];

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/helper/register', $payload);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.review_status', 'pending')
            ->assertJsonPath('data.helper_profile.hourly_rate', 25000)
            ->assertJsonPath('data.helper_profile.max_advance_limit', 150000);

        // Verifikasi berkas disimpan di disk
        $verification = VerificationRequest::where('user_id', $user->id)->first();
        $this->assertNotNull($verification);
        $this->assertEquals('pending', $verification->review_status);

        // User status berubah jadi pending
        $user->refresh();
        $this->assertEquals('pending', $user->verification_status);

        // Helper profile terbuat tetapi belum aktif
        $this->assertFalse($user->isVerifiedHelper());
        $this->assertNull($user->helperProfile->approved_at);
        $this->assertEquals(\App\Enums\HelperAvailability::UNAVAILABLE, $user->helperProfile->is_available);
        $this->assertFalse($user->helperProfile->isAvailable());
    }

    /**
     * Test validasi gagal jika kategori kosong atau melebihi 6 kategori.
     */
    public function test_registration_fails_if_categories_invalid(): void
    {
        Storage::fake(config('filesystems.default', 'r2'));

        $user = User::create([
            'full_name' => 'Tester Validasi',
            'email' => 'test_cat_' . time() . '@example.com',
            'phone_number' => '0853' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'unverified',
        ]);

        $payload = [
            'category_ids' => [], // Kosong! Minimal 1
            'hourly_rate' => 20000,
            'max_advance_limit' => 50000,
            'id_card_photo' => UploadedFile::fake()->create('ktp.jpg', 100, 'image/jpeg'),
            'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 100, 'image/jpeg'),
        ];

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/helper/register', $payload);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    /**
     * Test invarian erd_final.md: User tidak boleh mengajukan tiket verifikasi baru jika masih ada yang pending.
     */
    public function test_user_cannot_submit_if_pending_verification_already_exists(): void
    {
        Storage::fake(config('filesystems.default', 'r2'));

        $user = User::create([
            'full_name' => 'Pending User',
            'email' => 'pending_' . time() . '@example.com',
            'phone_number' => '0854' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'pending',
        ]);

        VerificationRequest::create([
            'user_id' => $user->id,
            'id_card_url' => '/storage/verifications/id_cards/test.jpg',
            'selfie_url' => '/storage/verifications/selfies/test.jpg',
            'review_status' => 'pending',
        ]);

        $categories = ServiceCategory::take(2)->pluck('id')->toArray();

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/helper/register', [
                'category_ids' => $categories,
                'hourly_rate' => 30000,
                'max_advance_limit' => 100000,
                'id_card_photo' => UploadedFile::fake()->create('ktp.jpg', 100, 'image/jpeg'),
                'selfie_photo' => UploadedFile::fake()->create('selfie.jpg', 100, 'image/jpeg'),
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VERIFICATION_PENDING_EXISTS');
    }

    /**
     * Test skenario A.1: Jika ditolak admin (misal foto buram), user dapat langsung mengajukan ulang tanpa cooldown.
     */
    public function test_rejected_user_can_immediately_resubmit(): void
    {
        Storage::fake(config('filesystems.default', 'r2'));

        $user = User::create([
            'full_name' => 'Rejected User',
            'email' => 'rejected_' . time() . '@example.com',
            'phone_number' => '0855' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'rejected',
        ]);

        VerificationRequest::create([
            'user_id' => $user->id,
            'id_card_url' => '/storage/verifications/id_cards/buram.jpg',
            'selfie_url' => '/storage/verifications/selfies/buram.jpg',
            'review_status' => 'rejected',
            'rejection_reason' => 'Foto KTP silau dan NIK tidak terbaca',
        ]);

        $categories = ServiceCategory::take(1)->pluck('id')->toArray();

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/helper/register', [
                'category_ids' => $categories,
                'hourly_rate' => 20000,
                'max_advance_limit' => 50000,
                'id_card_photo' => UploadedFile::fake()->create('ktp_terang.jpg', 100, 'image/jpeg'),
                'selfie_photo' => UploadedFile::fake()->create('selfie_terang.jpg', 100, 'image/jpeg'),
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.review_status', 'pending');

        $user->refresh();
        $this->assertEquals('pending', $user->verification_status);
    }

    /**
     * Test skenario A.2: Admin menyetujui pengajuan -> helper teraktivasi (verified).
     */
    public function test_admin_approval_activates_helper(): void
    {
        $admin = User::create([
            'full_name' => 'Mentor Admin',
            'email' => 'admin_' . time() . '@example.com',
            'phone_number' => '0811' . rand(10000000, 99999999),
            'password' => 'AdminPass123!',
            'is_admin' => true,
        ]);

        $helperUser = User::create([
            'full_name' => 'Calon Helper Hebat',
            'email' => 'calon_' . time() . '@example.com',
            'phone_number' => '0856' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'pending',
        ]);

        $helperProfile = HelperProfile::create([
            'user_id' => $helperUser->id,
            'hourly_rate' => 25000,
            'max_advance_limit' => 100000,
            'is_available' => false,
        ]);

        $verification = VerificationRequest::create([
            'user_id' => $helperUser->id,
            'id_card_url' => '/storage/ktp.jpg',
            'selfie_url' => '/storage/selfie.jpg',
            'review_status' => 'pending',
        ]);

        // Admin approve via /admin/verifications/{id}/approve
        $response = $this->actingAs($admin, 'sanctum')
            ->postJson("/admin/verifications/{$verification->id}/approve");

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.review_status', 'approved')
            ->assertJsonPath('data.is_available', 'available');

        $helperUser->refresh();
        $helperProfile->refresh();

        $this->assertEquals('verified', $helperUser->verification_status);
        $this->assertNotNull($helperProfile->approved_at);
        $this->assertEquals(\App\Enums\HelperAvailability::AVAILABLE, $helperProfile->is_available);
        $this->assertTrue($helperProfile->isAvailable());
        $this->assertTrue($helperUser->isVerifiedHelper());
    }

    /**
     * Test cek status helper terkini via /helper/status.
     */
    public function test_user_can_check_helper_status(): void
    {
        $user = User::create([
            'full_name' => 'Cek Status User',
            'email' => 'cek_' . time() . '@example.com',
            'phone_number' => '0857' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'rejected',
        ]);

        VerificationRequest::create([
            'user_id' => $user->id,
            'id_card_url' => '/storage/ktp.jpg',
            'selfie_url' => '/storage/selfie.jpg',
            'review_status' => 'rejected',
            'rejection_reason' => 'Foto KTP buram',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/helper/status');

        $response->assertStatus(200)
            ->assertJsonPath('data.verification_status', 'rejected')
            ->assertJsonPath('data.latest_verification.rejection_reason', 'Foto KTP buram');
    }

    /**
     * Test dashboard Client (/client/dashboard).
     */
    public function test_client_can_access_dashboard(): void
    {
        $user = User::create([
            'full_name' => 'Client Dashboard Tester',
            'email' => 'client_dash_' . time() . '@example.com',
            'phone_number' => '0858' . rand(10000000, 99999999),
            'password' => 'Password123!',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/client/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => [
                    'user' => ['id', 'full_name', 'email'],
                    'wallet' => ['available_balance', 'held_balance'],
                    'service_categories_count',
                    'active_helpers_count',
                ],
            ]);
    }

    /**
     * Test dashboard Helper (/helper/dashboard).
     */
    public function test_helper_can_access_dashboard(): void
    {
        $user = User::create([
            'full_name' => 'Helper Dashboard Tester',
            'email' => 'helper_dash_' . time() . '@example.com',
            'phone_number' => '0859' . rand(10000000, 99999999),
            'password' => 'Password123!',
            'verification_status' => 'verified',
        ]);

        HelperProfile::create([
            'user_id' => $user->id,
            'hourly_rate' => 20000,
            'is_available' => true,
            'approved_at' => now(),
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/helper/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.is_helper', true)
            ->assertJsonStructure([
                'data' => [
                    'is_helper',
                    'profile' => ['hourly_rate', 'is_available'],
                    'wallet' => ['available_balance'],
                ],
            ]);
    }

    /**
     * Test dashboard Admin (/admin/dashboard).
     */
    public function test_admin_can_access_dashboard(): void
    {
        $admin = User::create([
            'full_name' => 'Admin Dashboard Tester',
            'email' => 'admin_dash_' . time() . '@example.com',
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'AdminPass123!',
            'is_admin' => true,
        ]);

        $response = $this->actingAs($admin, 'sanctum')
            ->getJson('/admin/dashboard');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => [
                    'total_users',
                    'total_helpers_verified',
                    'pending_verifications',
                    'service_categories',
                ],
            ]);
    }
}
