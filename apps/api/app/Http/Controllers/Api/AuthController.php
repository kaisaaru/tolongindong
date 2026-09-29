<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\AuthRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected AuthRepositoryInterface $authRepo
    ) {}

    /**
     * Registrasi Akun Manual (FR-AUTH-001, FR-AUTH-003).
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
            return $this->errorResponse('Validasi pendaftaran gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->registerUser($validator->validated());

        return $this->successResponse(
            $result,
            'Pendaftaran berhasil. Silakan masukkan kode OTP 6-digit yang dikirim ke nomor Anda.',
            201
        );
    }

    /**
     * Verifikasi Kode OTP (FR-AUTH-002).
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
            'otp_code' => 'required|string|size:6',
            'temp_token' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi OTP gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->verifyOtp(
            $request->phone_number,
            $request->otp_code,
            $request->temp_token
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse(
            $result['data'],
            'Nomor telepon berhasil diverifikasi. Selamat datang di TolonginDong!'
        );
    }

    /**
     * Kirim Ulang Kode OTP.
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

        $result = $this->authRepo->sendOtp($request->phone_number, $request->type);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Kode OTP 6-digit berhasil dikirim.');
    }

    /**
     * Login Manual (Email atau Nomor HP + Password) (FR-AUTH-004, FR-AUTH-005).
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'identifier' => 'required|string',
            'password' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi login gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->attemptLogin($request->identifier, $request->password);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Login berhasil.');
    }

    /**
     * Login / Registrasi Google Sign-In.
     */
    public function google(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'id_token' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi Google token gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->handleGoogleSignIn($request->id_token);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        $message = !empty($result['data']['requires_phone_completion'])
            ? 'Akun Google terverifikasi. Silakan lengkapi nomor telepon untuk mengaktifkan akun.'
            : 'Login dengan Google berhasil.';

        return $this->successResponse($result['data'], $message);
    }

    /**
     * Dapatkan Profil Sesi Pengguna Saat Ini.
     */
    public function me(Request $request): JsonResponse
    {
        $profile = $this->authRepo->getUserProfile($request->user());

        return $this->successResponse($profile, 'Data profil pengguna.');
    }

    /**
     * Logout dan Cabut Token Sanctum.
     */
    public function logout(Request $request): JsonResponse
    {
        $this->authRepo->logout($request->user());

        return $this->successResponse(null, 'Logout berhasil.');
    }

    /**
     * Permintaan OTP Lupa Kata Sandi (FR-AUTH-006).
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
        ], [
            'phone_number.required' => 'Nomor telepon wajib diisi.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi nomor telepon gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->forgotPassword($request->phone_number);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Kode OTP pemulihan kata sandi berhasil dikirim.');
    }

    /**
     * Reset Kata Sandi Menggunakan OTP (FR-AUTH-006).
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'phone_number' => 'required|string',
            'otp_code' => 'required|string|size:6',
            'new_password' => 'required|string|min:8',
        ], [
            'phone_number.required' => 'Nomor telepon wajib diisi.',
            'otp_code.required' => 'Kode OTP 6-digit wajib diisi.',
            'otp_code.size' => 'Kode OTP harus berupa 6 digit angka.',
            'new_password.required' => 'Kata sandi baru wajib diisi.',
            'new_password.min' => 'Kata sandi baru minimal 8 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi reset kata sandi gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->resetPassword(
            $request->phone_number,
            $request->otp_code,
            $request->new_password
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message']);
    }

    /**
     * Ubah Kata Sandi di Sesi Aktif (atau pasang baru jika akun Google).
     */
    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();
        $rules = [
            'new_password' => 'required|string|min:8',
        ];

        // Jika akun sudah memiliki password, current_password wajib diisi
        if (!is_null($user->password)) {
            $rules['current_password'] = 'required|string';
        }

        $validator = Validator::make($request->all(), $rules, [
            'current_password.required' => 'Kata sandi saat ini wajib diisi.',
            'new_password.required' => 'Kata sandi baru wajib diisi.',
            'new_password.min' => 'Kata sandi baru minimal 8 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi ubah kata sandi gagal', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->changePassword(
            $user,
            $request->current_password,
            $request->new_password
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message']);
    }
}
