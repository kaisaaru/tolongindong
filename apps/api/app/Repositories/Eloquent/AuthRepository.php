<?php

namespace App\Repositories\Eloquent;

use App\Models\Otp;
use App\Models\User;
use App\Models\Wallet;
use App\Repositories\Contracts\AuthRepositoryInterface;
use Google\Client as GoogleClient;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthRepository implements AuthRepositoryInterface
{
    /**
     * Daftarkan user baru secara manual dan buatkan kode OTP.
     */
    public function registerUser(array $data): array
    {
        return DB::transaction(function () use ($data) {
            $user = User::create([
                'full_name' => $data['full_name'],
                'email' => $data['email'],
                'phone_number' => $data['phone_number'],
                'password' => $data['password'],
                'verification_status' => 'unverified',
                'is_admin' => false,
                'is_suspended' => false,
            ]);

            // Kode OTP 6 digit acak (300 detik)
            $otpCode = (string) random_int(100000, 999999);

            Otp::create([
                'phone_number' => $user->phone_number,
                'otp_code' => $otpCode,
                'type' => 'register',
                'expires_at' => now()->addSeconds(300),
            ]);

            $responseData = [
                'user_id' => $user->id,
                'phone_number' => $user->phone_number,
                'otp_expires_in_seconds' => 300,
            ];

            if (app()->environment('local')) {
                $responseData['debug_otp'] = $otpCode;
            }

            return $responseData;
        });
    }

    /**
     * Verifikasi kode OTP nomor telepon dan terbitkan token Sanctum.
     */
    public function verifyOtp(string $phoneNumber, string $otpCode, ?string $tempToken = null): array
    {
        $otp = Otp::where('phone_number', $phoneNumber)
            ->where('consumed_at', null)
            ->latest()
            ->first();

        if (!$otp || $otp->isExpired()) {
            return [
                'success' => false,
                'error_code' => 'OTP_EXPIRED',
                'message' => 'Kode OTP telah kedaluwarsa atau tidak ditemukan. Silakan kirim ulang kode.',
                'status_code' => 422,
            ];
        }

        if ($otp->otp_code !== $otpCode) {
            $otp->increment('attempts');
            return [
                'success' => false,
                'error_code' => 'OTP_INVALID',
                'message' => 'Kode OTP yang Anda masukkan salah.',
                'detail' => ['remaining_attempts' => max(0, 3 - $otp->attempts)],
                'status_code' => 422,
            ];
        }

        $otp->update(['consumed_at' => now()]);

        return DB::transaction(function () use ($phoneNumber, $tempToken) {
            // Kasus pendaftaran Google dengan temp_token
            if ($tempToken) {
                try {
                    $googleData = Crypt::decrypt($tempToken);
                } catch (\Exception $e) {
                    return [
                        'success' => false,
                        'error_code' => 'INVALID_TOKEN',
                        'message' => 'Sesi pendaftaran Google tidak valid atau telah kedaluwarsa.',
                        'status_code' => 400,
                    ];
                }

                if (User::where('phone_number', $phoneNumber)->exists()) {
                    return [
                        'success' => false,
                        'error_code' => 'PHONE_ALREADY_TAKEN',
                        'message' => 'Nomor telepon ini sudah digunakan oleh akun lain.',
                        'status_code' => 422,
                    ];
                }

                $user = User::create([
                    'full_name' => $googleData['full_name'],
                    'email' => $googleData['email'],
                    'google_id' => $googleData['google_id'],
                    'photo_url' => $googleData['photo_url'] ?? null,
                    'phone_number' => $phoneNumber,
                    'phone_verified_at' => now(),
                    'verification_status' => 'unverified',
                    'is_admin' => false,
                    'is_suspended' => false,
                ]);
            } else {
                $user = User::where('phone_number', $phoneNumber)->first();

                if (!$user) {
                    return [
                        'success' => false,
                        'error_code' => 'USER_NOT_FOUND',
                        'message' => 'Akun pengguna tidak ditemukan.',
                        'status_code' => 404,
                    ];
                }

                $user->update(['phone_verified_at' => now()]);
            }

            // Inisialisasi TD-Wallet
            $wallet = Wallet::firstOrCreate(
                ['user_id' => $user->id],
                ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
            );

            $token = $user->createToken('auth_token')->plainTextToken;

            return [
                'success' => true,
                'data' => [
                    'token' => $token,
                    'user' => [
                        'id' => $user->id,
                        'full_name' => $user->full_name,
                        'email' => $user->email,
                        'phone_number' => $user->phone_number,
                        'photo_url' => $user->photo_url,
                        'verification_status' => $user->verification_status,
                        'wallet' => [
                            'available_balance' => $wallet->available_balance,
                            'held_balance' => $wallet->held_balance,
                            'currency' => $wallet->currency,
                        ],
                    ],
                ],
            ];
        });
    }

    /**
     * Kirim ulang kode OTP ke nomor telepon.
     */
    public function sendOtp(string $phoneNumber, ?string $type = 'register'): array
    {
        $throttleKey = 'otp_send:' . $phoneNumber;

        if (RateLimiter::tooManyAttempts($throttleKey, 1)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            return [
                'success' => false,
                'error_code' => 'OTP_THROTTLED',
                'message' => "Mohon tunggu {$seconds} detik sebelum meminta kode OTP baru.",
                'detail' => ['retry_after_seconds' => $seconds],
                'status_code' => 429,
            ];
        }

        RateLimiter::hit($throttleKey, 60);

        $otpCode = (string) random_int(100000, 999999);

        Otp::create([
            'phone_number' => $phoneNumber,
            'otp_code' => $otpCode,
            'type' => $type ?? 'register',
            'expires_at' => now()->addSeconds(300),
        ]);

        $responseData = [
            'phone_number' => $phoneNumber,
            'otp_expires_in_seconds' => 300,
        ];

        if (app()->environment('local')) {
            $responseData['debug_otp'] = $otpCode;
        }

        return [
            'success' => true,
            'data' => $responseData,
        ];
    }

    /**
     * Lakukan autentikasi manual dengan email/nomor HP dan kata sandi.
     */
    public function attemptLogin(string $identifier, string $password): array
    {
        $throttleKey = 'login:' . Str::lower($identifier);

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            return [
                'success' => false,
                'error_code' => 'ACCOUNT_LOCKED',
                'message' => "Terlalu banyak percobaan login gagal. Akun dikunci sementara. Silakan coba lagi dalam {$seconds} detik.",
                'detail' => ['lockout_seconds' => $seconds],
                'status_code' => 429,
            ];
        }

        $user = User::where('email', $identifier)
            ->orWhere('phone_number', $identifier)
            ->first();

        if (!$user) {
            RateLimiter::hit($throttleKey, 900);
            $remaining = 5 - RateLimiter::attempts($throttleKey);

            return [
                'success' => false,
                'error_code' => 'INVALID_CREDENTIALS',
                'message' => 'Nomor telepon / email atau kata sandi salah.',
                'detail' => ['remaining_attempts' => max(0, $remaining)],
                'status_code' => 401,
            ];
        }

        // Jika akun terdaftar via Google dan belum mengatur kata sandi manual
        if (is_null($user->password) && !is_null($user->google_id)) {
            return [
                'success' => false,
                'error_code' => 'SOCIAL_AUTH_ACCOUNT',
                'message' => "Akun ini terdaftar menggunakan Google. Silakan masuk menggunakan tombol 'Sign in with Google'.",
                'status_code' => 400,
            ];
        }

        if (!Hash::check($password, $user->password)) {
            RateLimiter::hit($throttleKey, 900);
            $remaining = 5 - RateLimiter::attempts($throttleKey);

            return [
                'success' => false,
                'error_code' => 'INVALID_CREDENTIALS',
                'message' => 'Nomor telepon / email atau kata sandi salah.',
                'detail' => ['remaining_attempts' => max(0, $remaining)],
                'status_code' => 401,
            ];
        }

        if ($user->is_suspended) {
            return [
                'success' => false,
                'error_code' => 'ACCOUNT_SUSPENDED',
                'message' => 'Akun Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan layanan'),
                'status_code' => 403,
            ];
        }

        RateLimiter::clear($throttleKey);

        $wallet = Wallet::firstOrCreate(
            ['user_id' => $user->id],
            ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
        );

        $token = $user->createToken('auth_token')->plainTextToken;

        return [
            'success' => true,
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'full_name' => $user->full_name,
                    'email' => $user->email,
                    'phone_number' => $user->phone_number,
                    'photo_url' => $user->photo_url,
                    'verification_status' => $user->verification_status,
                    'is_admin' => $user->is_admin,
                    'wallet' => [
                        'available_balance' => $wallet->available_balance,
                        'held_balance' => $wallet->held_balance,
                        'currency' => $wallet->currency,
                    ],
                ],
            ],
        ];
    }

    /**
     * Tangani autentikasi Google OAuth dengan ID Token.
     */
    public function handleGoogleSignIn(string $idToken): array
    {
        if (app()->environment('local', 'testing') && (Str::startsWith($idToken, 'mock-') || $idToken === 'test-google-token')) {
            $googleId = 'mock_google_' . Str::random(8);
            $email = Str::contains($idToken, 'returning') ? 'returning.mock@example.com' : ('user.mock.' . Str::random(6) . '@example.com');
            $fullName = 'Pengguna Google Uji Coba';
            $photoUrl = 'https://ui-avatars.com/api/?name=Google+User';
        } else {
            try {
                $client = new GoogleClient(['client_id' => config('services.google.client_id')]);
                $payload = $client->verifyIdToken($idToken);

                if (!$payload) {
                    return [
                        'success' => false,
                        'error_code' => 'INVALID_GOOGLE_TOKEN',
                        'message' => 'Google ID Token tidak valid atau kedaluwarsa.',
                        'status_code' => 401,
                    ];
                }

                $googleId = $payload['sub'];
                $email = $payload['email'];
                $fullName = $payload['name'] ?? 'Pengguna Google';
                $photoUrl = $payload['picture'] ?? null;
            } catch (\Exception $e) {
                return [
                    'success' => false,
                    'error_code' => 'GOOGLE_AUTH_ERROR',
                    'message' => 'Gagal memverifikasi token Google: ' . $e->getMessage(),
                    'status_code' => 500,
                ];
            }
        }

        $user = User::where('google_id', $googleId)
            ->orWhere('email', $email)
            ->first();

        // Returning user dengan nomor telepon terverifikasi
        if ($user && $user->phone_number && $user->phone_verified_at) {
            if ($user->is_suspended) {
                return [
                    'success' => false,
                    'error_code' => 'ACCOUNT_SUSPENDED',
                    'message' => 'Akun Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan'),
                    'status_code' => 403,
                ];
            }

            if (!$user->google_id) {
                $user->update(['google_id' => $googleId]);
            }

            $wallet = Wallet::firstOrCreate(
                ['user_id' => $user->id],
                ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
            );

            $token = $user->createToken('auth_token')->plainTextToken;

            return [
                'success' => true,
                'data' => [
                    'requires_phone_completion' => false,
                    'token' => $token,
                    'user' => [
                        'id' => $user->id,
                        'full_name' => $user->full_name,
                        'email' => $user->email,
                        'phone_number' => $user->phone_number,
                        'photo_url' => $user->photo_url,
                        'verification_status' => $user->verification_status,
                        'wallet' => [
                            'available_balance' => $wallet->available_balance,
                            'held_balance' => $wallet->held_balance,
                            'currency' => $wallet->currency,
                        ],
                    ],
                ],
            ];
        }

        // New user: temp_token lazy insert
        $tempToken = Crypt::encrypt([
            'google_id' => $googleId,
            'email' => $email,
            'full_name' => $fullName,
            'photo_url' => $photoUrl,
            'expires_at' => now()->addMinutes(30)->timestamp,
        ]);

        return [
            'success' => true,
            'data' => [
                'requires_phone_completion' => true,
                'temp_token' => $tempToken,
                'profile' => [
                    'full_name' => $fullName,
                    'email' => $email,
                    'photo_url' => $photoUrl,
                ],
            ],
        ];
    }

    /**
     * Dapatkan detail profil user dan wallet.
     */
    public function getUserProfile(User $user): array
    {
        $user->load('wallet');

        return [
            'id' => $user->id,
            'full_name' => $user->full_name,
            'email' => $user->email,
            'phone_number' => $user->phone_number,
            'photo_url' => $user->photo_url,
            'verification_status' => $user->verification_status,
            'is_admin' => $user->is_admin,
            'wallet' => $user->wallet ? [
                'available_balance' => $user->wallet->available_balance,
                'held_balance' => $user->wallet->held_balance,
                'currency' => $user->wallet->currency,
            ] : null,
        ];
    }

    /**
     * Cabut access token user (logout).
     */
    public function logout(User $user): void
    {
        $user->currentAccessToken()->delete();
    }

    /**
     * Kirim OTP untuk pemulihan kata sandi (FR-AUTH-006).
     */
    public function forgotPassword(string $phoneNumber): array
    {
        $user = User::where('phone_number', $phoneNumber)->first();

        if (!$user) {
            return [
                'success' => false,
                'error_code' => 'USER_NOT_FOUND',
                'message' => 'Nomor telepon tidak terdaftar dalam sistem.',
                'status_code' => 404,
            ];
        }

        if ($user->is_suspended) {
            return [
                'success' => false,
                'error_code' => 'ACCOUNT_SUSPENDED',
                'message' => 'Akun Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan layanan'),
                'status_code' => 403,
            ];
        }

        return $this->sendOtp($phoneNumber, 'reset_password');
    }

    /**
     * Reset kata sandi dengan kode OTP nomor telepon (FR-AUTH-006).
     */
    public function resetPassword(string $phoneNumber, string $otpCode, string $newPassword): array
    {
        $user = User::where('phone_number', $phoneNumber)->first();

        if (!$user) {
            return [
                'success' => false,
                'error_code' => 'USER_NOT_FOUND',
                'message' => 'Nomor telepon tidak terdaftar dalam sistem.',
                'status_code' => 404,
            ];
        }

        $otp = Otp::where('phone_number', $phoneNumber)
            ->where('type', 'reset_password')
            ->whereNull('consumed_at')
            ->latest('created_at')
            ->first();

        if (!$otp || $otp->isExpired()) {
            return [
                'success' => false,
                'error_code' => 'OTP_EXPIRED',
                'message' => 'Kode OTP telah kedaluwarsa. Silakan minta kode baru.',
                'status_code' => 422,
            ];
        }

        if ($otp->attempts >= 3) {
            return [
                'success' => false,
                'error_code' => 'OTP_MAX_ATTEMPTS',
                'message' => 'Batas percobaan OTP terlampaui. Silakan minta kode baru.',
                'status_code' => 422,
            ];
        }

        if ($otp->otp_code !== $otpCode) {
            $otp->increment('attempts');

            return [
                'success' => false,
                'error_code' => 'OTP_INVALID',
                'message' => 'Kode OTP yang Anda masukkan salah.',
                'detail' => ['remaining_attempts' => max(0, 3 - $otp->attempts)],
                'status_code' => 422,
            ];
        }

        $otp->update(['consumed_at' => now()]);
        $user->update(['password' => Hash::make($newPassword)]);

        return [
            'success' => true,
            'message' => 'Kata sandi berhasil diperbarui. Silakan masuk menggunakan kata sandi baru Anda.',
            'data' => [
                'user_id' => $user->id,
                'phone_number' => $user->phone_number,
            ],
        ];
    }

    /**
     * Ganti kata sandi dengan kata sandi lama (atau pasang baru jika akun Google).
     */
    public function changePassword(User $user, ?string $currentPassword, string $newPassword): array
    {
        // Jika akun sudah memiliki kata sandi lama, wajib verifikasi kata sandi saat ini
        if (!is_null($user->password)) {
            if (!$currentPassword || !Hash::check($currentPassword, $user->password)) {
                return [
                    'success' => false,
                    'error_code' => 'CURRENT_PASSWORD_INCORRECT',
                    'message' => 'Kata sandi saat ini yang Anda masukkan salah.',
                    'status_code' => 422,
                ];
            }
        }

        $user->update(['password' => Hash::make($newPassword)]);

        return [
            'success' => true,
            'message' => 'Kata sandi berhasil disimpan.',
            'data' => [
                'user_id' => $user->id,
                'has_password' => true,
            ],
        ];
    }
}
