<?php

namespace App\Repositories\Contracts;

use App\Models\User;

interface AuthRepositoryInterface
{
    /**
     * Daftarkan user baru secara manual dan buatkan kode OTP.
     */
    public function registerUser(array $data): array;

    /**
     * Verifikasi kode OTP nomor telepon dan terbitkan token Sanctum.
     */
    public function verifyOtp(string $phoneNumber, string $otpCode, ?string $tempToken = null): array;

    /**
     * Kirim ulang kode OTP ke nomor telepon.
     */
    public function sendOtp(string $phoneNumber, ?string $type = 'register'): array;

    /**
     * Lakukan autentikasi manual dengan email/nomor HP dan kata sandi.
     */
    public function attemptLogin(string $identifier, string $password): array;

    /**
     * Lakukan autentikasi khusus admin (FR-ADM-001, API-ADM-01).
     */
    public function attemptAdminLogin(string $identifier, string $password): array;

    /**
     * Tangani autentikasi Google OAuth dengan ID Token.
     */
    public function handleGoogleSignIn(string $idToken): array;

    /**
     * Dapatkan detail profil user dan wallet.
     */
    public function getUserProfile(User $user): array;

    /**
     * Cabut access token user (logout).
     */
    public function logout(User $user): void;

    /**
     * Kirim OTP untuk pemulihan kata sandi (FR-AUTH-006).
     */
    public function forgotPassword(string $phoneNumber): array;

    /**
     * Reset kata sandi dengan kode OTP nomor telepon (FR-AUTH-006).
     */
    public function resetPassword(string $phoneNumber, string $otpCode, string $newPassword): array;

    /**
     * Ganti kata sandi dengan kata sandi lama (atau pasang baru jika akun Google).
     */
    public function changePassword(User $user, ?string $currentPassword, string $newPassword): array;
}
