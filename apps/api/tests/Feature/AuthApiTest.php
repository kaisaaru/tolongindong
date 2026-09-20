<?php

namespace Tests\Feature;

use App\Models\Otp;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use DatabaseTransactions;

    /**
     * Test registrasi manual berhasil dan menerbitkan OTP.
     */
    public function test_user_can_register_manually(): void
    {
        $unique = time();
        $payload = [
            'full_name' => 'Budi Santoso',
            'email' => "budi_{$unique}@example.com",
            'phone_number' => "0812999{$unique}",
            'password' => 'Rahasia123!',
        ];

        $response = $this->postJson('/register', $payload);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'user_id',
                    'phone_number',
                    'otp_expires_in_seconds',
                ],
                'meta' => [
                    'request_id',
                    'server_time',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => "budi_{$unique}@example.com",
            'verification_status' => 'unverified',
        ]);

        $this->assertDatabaseHas('otps', [
            'phone_number' => "0812999{$unique}",
            'type' => 'register',
        ]);
    }

    /**
     * Test verifikasi OTP mengaktifkan akun, membuat wallet, dan menghasilkan token Sanctum.
     */
    public function test_user_can_verify_otp_and_receive_wallet(): void
    {
        $unique = time() + 1;
        $phoneNumber = "0813999{$unique}";

        $user = User::create([
            'full_name' => 'Siti Aisyah',
            'email' => "siti_{$unique}@example.com",
            'phone_number' => $phoneNumber,
            'password' => 'Rahasia123!',
            'verification_status' => 'unverified',
        ]);

        Otp::create([
            'phone_number' => $phoneNumber,
            'otp_code' => '123456',
            'type' => 'register',
            'expires_at' => now()->addMinutes(5),
        ]);

        $response = $this->postJson('/verify-otp', [
            'phone_number' => $phoneNumber,
            'otp_code' => '123456',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => [
                        'id',
                        'full_name',
                        'email',
                        'phone_number',
                        'wallet' => [
                            'available_balance',
                            'held_balance',
                            'currency',
                        ],
                    ],
                ],
            ]);

        // Verifikasi wallet dibuat dengan saldo 0
        $this->assertDatabaseHas('wallets', [
            'user_id' => $user->id,
            'available_balance' => 0,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);
    }

    /**
     * Test login manual menggunakan email atau nomor telepon.
     */
    public function test_user_can_login_with_email_or_phone(): void
    {
        $unique = time() + 2;
        $email = "tono_{$unique}@example.com";
        $phone = "0814999{$unique}";

        $user = User::create([
            'full_name' => 'Hartono',
            'email' => $email,
            'phone_number' => $phone,
            'password' => 'Password123!',
            'phone_verified_at' => now(),
        ]);

        Wallet::create([
            'user_id' => $user->id,
            'available_balance' => 50000,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);

        // 1. Login dengan Email
        $responseEmail = $this->postJson('/login', [
            'identifier' => $email,
            'password' => 'Password123!',
        ]);
        $responseEmail->assertStatus(200)->assertJsonPath('data.user.email', $email);

        // 2. Login dengan Nomor Telepon
        $responsePhone = $this->postJson('/login', [
            'identifier' => $phone,
            'password' => 'Password123!',
        ]);
        $responsePhone->assertStatus(200)->assertJsonPath('data.user.phone_number', $phone);

        // 3. Login gagal dengan kata sandi keliru
        $responseFail = $this->postJson('/login', [
            'identifier' => $email,
            'password' => 'SalahPassword!',
        ]);
        $responseFail->assertStatus(401)->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
    }

    /**
     * Test Google Sign-In alur pengguna baru (memerlukan lengkapi nomor telepon).
     */
    public function test_google_sign_in_new_user_requests_phone_completion(): void
    {
        $response = $this->postJson('/google', [
            'id_token' => 'mock-google-token-new',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.requires_phone_completion', true)
            ->assertJsonStructure([
                'data' => [
                    'temp_token',
                    'profile' => ['full_name', 'email'],
                ],
            ]);
    }

    /**
     * Test pengguna Google tanpa password mencoba login manual mendapat pesan SOCIAL_AUTH_ACCOUNT.
     */
    public function test_google_user_without_password_receives_social_auth_notice_on_manual_login(): void
    {
        $unique = time() + 5;
        $user = User::create([
            'full_name' => 'Google User',
            'email' => "google_{$unique}@example.com",
            'phone_number' => "0815999{$unique}",
            'google_id' => "gid_{$unique}",
            'password' => null, // Tidak punya password
            'phone_verified_at' => now(),
        ]);

        $response = $this->postJson('/login', [
            'identifier' => "0815999{$unique}",
            'password' => 'SembarangPassword123!',
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'SOCIAL_AUTH_ACCOUNT')
            ->assertJsonPath('success', false);
    }

    /**
     * Test alur Lupa Password (FR-AUTH-006): Kirim OTP dan Reset Password.
     */
    public function test_user_can_forgot_and_reset_password_with_otp(): void
    {
        $unique = time() + 10;
        $phoneNumber = "0816999{$unique}";

        $user = User::create([
            'full_name' => 'Lupa Password User',
            'email' => "lupa_{$unique}@example.com",
            'phone_number' => $phoneNumber,
            'password' => bcrypt('PasswordLama123!'),
            'phone_verified_at' => now(),
        ]);

        // 1. Minta OTP Lupa Password
        $forgotRes = $this->postJson('/password/forgot', [
            'phone_number' => $phoneNumber,
        ]);

        $forgotRes->assertStatus(200)
            ->assertJsonPath('success', true);

        $otp = Otp::where('phone_number', $phoneNumber)
            ->where('type', 'reset_password')
            ->latest('created_at')
            ->first();

        $this->assertNotNull($otp);

        // 2. Reset Kata Sandi dengan OTP Valid
        $resetRes = $this->postJson('/password/reset', [
            'phone_number' => $phoneNumber,
            'otp_code' => $otp->otp_code,
            'new_password' => 'PasswordBaru999!',
        ]);

        $resetRes->assertStatus(200)
            ->assertJsonPath('success', true);

        // 3. Login dengan kata sandi baru berhasil
        $loginRes = $this->postJson('/login', [
            'identifier' => $phoneNumber,
            'password' => 'PasswordBaru999!',
        ]);

        $loginRes->assertStatus(200)
            ->assertJsonPath('success', true);
    }

    /**
     * Test ganti password di sesi login (auth:sanctum) dengan password lama.
     */
    public function test_authenticated_user_can_change_password_with_current_password(): void
    {
        $unique = time() + 11;
        $user = User::create([
            'full_name' => 'Change PW User',
            'email' => "change_{$unique}@example.com",
            'phone_number' => "0817999{$unique}",
            'password' => bcrypt('PasswordLama123!'),
            'phone_verified_at' => now(),
        ]);

        // 1. Gagal jika kata sandi lama salah
        $failRes = $this->actingAs($user, 'sanctum')->postJson('/password/change', [
            'current_password' => 'PasswordSalah!',
            'new_password' => 'PasswordBaru888!',
        ]);

        $failRes->assertStatus(422)
            ->assertJsonPath('error.code', 'CURRENT_PASSWORD_INCORRECT');

        // 2. Berhasil jika kata sandi lama benar
        $successRes = $this->actingAs($user, 'sanctum')->postJson('/password/change', [
            'current_password' => 'PasswordLama123!',
            'new_password' => 'PasswordBaru888!',
        ]);

        $successRes->assertStatus(200)
            ->assertJsonPath('success', true);
    }

    /**
     * Test pengguna Google di sesi login (auth:sanctum) langsung bisa pasang password baru tanpa password lama.
     */
    public function test_authenticated_google_user_can_set_password_without_current_password(): void
    {
        $unique = time() + 12;
        $user = User::create([
            'full_name' => 'Google Set PW User',
            'email' => "gset_{$unique}@example.com",
            'phone_number' => "0818999{$unique}",
            'google_id' => "gid_set_{$unique}",
            'password' => null, // Belum punya password
            'phone_verified_at' => now(),
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/password/change', [
            'new_password' => 'PasswordBaruGoogle777!',
        ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        // Setelah disetel, user bisa login manual dengan password baru
        $loginRes = $this->postJson('/login', [
            'identifier' => "0818999{$unique}",
            'password' => 'PasswordBaruGoogle777!',
        ]);

        $loginRes->assertStatus(200)
            ->assertJsonPath('success', true);
    }
}
