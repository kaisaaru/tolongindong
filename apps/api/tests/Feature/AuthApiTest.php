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

        $response = $this->postJson('/api/v1/auth/register', $payload);

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

        $response = $this->postJson('/api/v1/auth/verify-otp', [
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
        $responseEmail = $this->postJson('/api/v1/auth/login', [
            'identifier' => $email,
            'password' => 'Password123!',
        ]);
        $responseEmail->assertStatus(200)->assertJsonPath('data.user.email', $email);

        // 2. Login dengan Nomor Telepon
        $responsePhone = $this->postJson('/api/v1/auth/login', [
            'identifier' => $phone,
            'password' => 'Password123!',
        ]);
        $responsePhone->assertStatus(200)->assertJsonPath('data.user.phone_number', $phone);

        // 3. Login gagal dengan kata sandi keliru
        $responseFail = $this->postJson('/api/v1/auth/login', [
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
        $response = $this->postJson('/api/v1/auth/google', [
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
}
