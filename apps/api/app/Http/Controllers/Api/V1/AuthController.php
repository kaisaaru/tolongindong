<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Otp;
use App\Models\User;
use App\Models\Wallet;
use App\Traits\ApiResponse;
use Google\Client as GoogleClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    use ApiResponse;

    /**
     * FR-AUTH-001 & FR-AUTH-003: Registrasi Akun Manual
     */
    public function register(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'full_name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'phone_number' => 'required|string|max:20|unique:users,phone_number',
            'password' => 'required|string|min:8',
        ], [
            'email.unique' => 'Alamat email ini sudah terdaftar. Silakan gunakan email lain atau login.',
            'phone_number.unique' => 'Nomor telepon ini sudah terdaftar. Silakan gunakan nomor lain atau login.',
            'password.min' => 'Kata sandi minimal harus terdiri dari 8 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse(
                'Validasi pendaftaran gagal',
                'VALIDATION_ERROR',
                $validator->errors(),
                422
            );
        }

        return DB::transaction(function () use ($request) {
            $user = User::create([
                'full_name' => $request->full_name,
                'email' => $request->email,
                'phone_number' => $request->phone_number,
                'password' => $request->password,
                'verification_status' => 'unverified',
                'is_admin' => false,
                'is_suspended' => false,
            ]);

            // Buat OTP 6 digit acak (berlaku 300 detik sesuai FR-AUTH-002)
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

            return $this->successResponse(
                $responseData,
                'Pendaftaran berhasil. Silakan masukkan kode OTP 6-digit yang dikirim ke nomor Anda.',
                201
            );
        });
    }

    /**
     * FR-AUTH-002: Verifikasi Kode OTP (Mengaktifkan Akun & Inisialisasi Wallet)
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
            'otp_code' => 'required|string|size:6',
            'temp_token' => 'nullable|string', // Digunakan jika berasal dari pendaftaran Google
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi OTP gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $otp = Otp::where('phone_number', $request->phone_number)
            ->where('consumed_at', null)
            ->latest()
            ->first();

        if (!$otp || $otp->isExpired()) {
            return $this->errorResponse(
                'Kode OTP telah kedaluwarsa atau tidak ditemukan. Silakan kirim ulang kode.',
                'OTP_EXPIRED',
                null,
                422
            );
        }

        if ($otp->otp_code !== $request->otp_code) {
            $otp->increment('attempts');
            return $this->errorResponse(
                'Kode OTP yang Anda masukkan salah.',
                'OTP_INVALID',
                ['remaining_attempts' => max(0, 3 - $otp->attempts)],
                422
            );
        }

        // Tandai OTP telah dikonsumsi
        $otp->update(['consumed_at' => now()]);

        return DB::transaction(function () use ($request) {
            // Kasus A: Verifikasi pendaftaran Google via temp_token
            if ($request->filled('temp_token')) {
                try {
                    $googleData = Crypt::decrypt($request->temp_token);
                } catch (\Exception $e) {
                    return $this->errorResponse('Sesi pendaftaran Google tidak valid atau telah kedaluwarsa.', 'INVALID_TOKEN', null, 400);
                }

                // Cek apakah nomor telepon sudah dipakai akun lain
                if (User::where('phone_number', $request->phone_number)->exists()) {
                    return $this->errorResponse('Nomor telepon ini sudah digunakan oleh akun lain.', 'PHONE_ALREADY_TAKEN', null, 422);
                }

                $user = User::create([
                    'full_name' => $googleData['full_name'],
                    'email' => $googleData['email'],
                    'google_id' => $googleData['google_id'],
                    'photo_url' => $googleData['photo_url'] ?? null,
                    'phone_number' => $request->phone_number,
                    'phone_verified_at' => now(),
                    'verification_status' => 'unverified',
                    'is_admin' => false,
                    'is_suspended' => false,
                ]);
            } else {
                // Kasus B: Verifikasi pendaftaran manual biasa
                $user = User::where('phone_number', $request->phone_number)->first();

                if (!$user) {
                    return $this->errorResponse('Akun pengguna tidak ditemukan.', 'USER_NOT_FOUND', null, 404);
                }

                $user->update([
                    'phone_verified_at' => now(),
                ]);
            }

            // Inisialisasi TD-Wallet dengan saldo 0 jika belum punya (invarian sistem)
            $wallet = Wallet::firstOrCreate(
                ['user_id' => $user->id],
                [
                    'available_balance' => 0,
                    'held_balance' => 0,
                    'currency' => 'IDR',
                ]
            );

            // Terbitkan Token Sanctum
            $token = $user->createToken('auth_token')->plainTextToken;

            return $this->successResponse([
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
            ], 'Nomor telepon berhasil diverifikasi. Selamat datang di TolonginDong!');
        });
    }

    /**
     * FR-AUTH-004 & FR-AUTH-005: Login Manual (Email atau Nomor HP + Password)
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'identifier' => 'required|string', // Bisa email atau phone_number
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi login gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $identifier = $request->identifier;
        $throttleKey = 'login:' . Str::lower($identifier);

        // FR-AUTH-005: Kunci percobaan login selama 900 detik setelah 5 kegagalan
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            return $this->errorResponse(
                "Terlalu banyak percobaan login gagal. Akun dikunci sementara. Silakan coba lagi dalam {$seconds} detik.",
                'ACCOUNT_LOCKED',
                ['lockout_seconds' => $seconds],
                429
            );
        }

        $user = User::where('email', $identifier)
            ->orWhere('phone_number', $identifier)
            ->first();

        if (!$user || !$user->password || !Hash::check($request->password, $user->password)) {
            RateLimiter::hit($throttleKey, 900); // Penalti 900 detik (15 menit)
            $remaining = 5 - RateLimiter::attempts($throttleKey);

            return $this->errorResponse(
                'Nomor telepon / email atau kata sandi salah.',
                'INVALID_CREDENTIALS',
                ['remaining_attempts' => max(0, $remaining)],
                401
            );
        }

        // Cek apakah akun ditangguhkan (suspended)
        if ($user->is_suspended) {
            return $this->errorResponse(
                'Akun Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan layanan'),
                'ACCOUNT_SUSPENDED',
                null,
                403
            );
        }

        // Reset hit rate limiter jika login sukses
        RateLimiter::clear($throttleKey);

        // Pastikan akun memiliki wallet
        $wallet = Wallet::firstOrCreate(
            ['user_id' => $user->id],
            [
                'available_balance' => 0,
                'held_balance' => 0,
                'currency' => 'IDR',
            ]
        );

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->successResponse([
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
        ], 'Login berhasil.');
    }

    /**
     * Login / Registrasi via Google Sign-In (ID Token Verification)
     */
    public function google(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'id_token' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi Google token gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $idToken = $request->id_token;

        // Mode Mock / Development untuk kemudahan testing lokal tanpa Flutter
        if (app()->environment('local', 'testing') && (Str::startsWith($idToken, 'mock-') || $idToken === 'test-google-token')) {
            $googleId = 'mock_google_' . Str::random(8);
            $email = 'user.mock@example.com';
            $fullName = 'Pengguna Google Uji Coba';
            $photoUrl = 'https://ui-avatars.com/api/?name=Google+User';
        } else {
            try {
                $client = new GoogleClient(['client_id' => config('services.google.client_id')]);
                $payload = $client->verifyIdToken($idToken);

                if (!$payload) {
                    return $this->errorResponse('Google ID Token tidak valid atau kedaluwarsa.', 'INVALID_GOOGLE_TOKEN', null, 401);
                }

                $googleId = $payload['sub'];
                $email = $payload['email'];
                $fullName = $payload['name'] ?? 'Pengguna Google';
                $photoUrl = $payload['picture'] ?? null;
            } catch (\Exception $e) {
                return $this->errorResponse('Gagal memverifikasi token Google: ' . $e->getMessage(), 'GOOGLE_AUTH_ERROR', null, 500);
            }
        }

        // Cek apakah user sudah terdaftar di database
        $user = User::where('google_id', $googleId)
            ->orWhere('email', $email)
            ->first();

        // Jika user sudah ada dan nomor telepon sudah diverifikasi -> Langsung Login!
        if ($user && $user->phone_number && $user->phone_verified_at) {
            if ($user->is_suspended) {
                return $this->errorResponse(
                    'Akun Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan'),
                    'ACCOUNT_SUSPENDED',
                    null,
                    403
                );
            }

            // Update google_id jika sebelumnya user terdaftar manual dengan email yang sama
            if (!$user->google_id) {
                $user->update(['google_id' => $googleId]);
            }

            $wallet = Wallet::firstOrCreate(
                ['user_id' => $user->id],
                ['available_balance' => 0, 'held_balance' => 0, 'currency' => 'IDR']
            );

            $token = $user->createToken('auth_token')->plainTextToken;

            return $this->successResponse([
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
            ], 'Login dengan Google berhasil.');
        }

        // Jika user baru / belum ada nomor telepon -> Kembalikan temp_token (Pola Lazy Insert)
        $tempToken = Crypt::encrypt([
            'google_id' => $googleId,
            'email' => $email,
            'full_name' => $fullName,
            'photo_url' => $photoUrl,
            'expires_at' => now()->addMinutes(30)->timestamp,
        ]);

        return $this->successResponse([
            'requires_phone_completion' => true,
            'temp_token' => $tempToken,
            'profile' => [
                'full_name' => $fullName,
                'email' => $email,
                'photo_url' => $photoUrl,
            ],
        ], 'Akun Google terverifikasi. Silakan lengkapi nomor telepon untuk mengaktifkan akun.');
    }

    /**
     * Kirim Ulang Kode OTP ke Nomor Telepon
     */
    public function sendOtp(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
            'type' => 'nullable|string|in:register,login,reset_password',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi nomor telepon gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $phoneNumber = $request->phone_number;
        $throttleKey = 'otp_send:' . $phoneNumber;

        // Batasi pengiriman OTP 1 kali per 60 detik
        if (RateLimiter::tooManyAttempts($throttleKey, 1)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            return $this->errorResponse(
                "Mohon tunggu {$seconds} detik sebelum meminta kode OTP baru.",
                'OTP_THROTTLED',
                ['retry_after_seconds' => $seconds],
                429
            );
        }

        RateLimiter::hit($throttleKey, 60);

        // Buat OTP 6 digit acak
        $otpCode = (string) random_int(100000, 999999);

        Otp::create([
            'phone_number' => $phoneNumber,
            'otp_code' => $otpCode,
            'type' => $request->type ?? 'register',
            'expires_at' => now()->addSeconds(300),
        ]);

        $responseData = [
            'phone_number' => $phoneNumber,
            'otp_expires_in_seconds' => 300,
        ];

        if (app()->environment('local')) {
            $responseData['debug_otp'] = $otpCode;
        }

        return $this->successResponse($responseData, 'Kode OTP 6-digit berhasil dikirim.');
    }

    /**
     * Dapatkan Profil Pengguna Saat Ini (Authenticated)
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load('wallet');

        return $this->successResponse([
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
        ], 'Data profil pengguna.');
    }

    /**
     * Logout dan Cabut Token Sanctum Saat Ini
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->successResponse(null, 'Logout berhasil.');
    }
}
