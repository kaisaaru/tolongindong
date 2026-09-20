<?php

use App\Http\Controllers\Api\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Api\Admin\VerificationController as AdminVerificationController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\HelperController;
use App\Http\Controllers\Api\ServiceCategoryController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes - TolonginDong (Direct Endpoints without /api/ or /v1/ prefix)
|--------------------------------------------------------------------------
*/

// 1. Public Auth & Umum
Route::post('/register', [AuthController::class, 'register'])->name('auth.register');
Route::post('/verify-otp', [AuthController::class, 'verifyOtp'])->name('auth.verify_otp');
Route::post('/send-otp', [AuthController::class, 'sendOtp'])->name('auth.send_otp');
Route::post('/login', [AuthController::class, 'login'])->name('auth.login');
Route::post('/google', [AuthController::class, 'google'])->name('auth.google');

// Pemulihan & Reset Kata Sandi (FR-AUTH-006)
Route::post('/password/forgot', [AuthController::class, 'forgotPassword'])->name('auth.password.forgot');
Route::post('/password/reset', [AuthController::class, 'resetPassword'])->name('auth.password.reset');

// 2. Public Kategori Layanan
Route::get('/service-categories', [ServiceCategoryController::class, 'index'])->name('service_categories.index');

// 3. Protected Endpoints (auth:sanctum)
Route::middleware('auth:sanctum')->group(function () {
    // Sesi & Keamanan Akun
    Route::get('/me', [AuthController::class, 'me'])->name('auth.me');
    Route::post('/logout', [AuthController::class, 'logout'])->name('auth.logout');
    Route::post('/password/change', [AuthController::class, 'changePassword'])->name('auth.password.change');

    // Modul Client
    Route::prefix('client')->name('client.')->group(function () {
        Route::get('/dashboard', [ClientController::class, 'dashboard'])->name('dashboard');
    });

    // Modul Helper
    Route::prefix('helper')->name('helper.')->group(function () {
        Route::post('/register', [HelperController::class, 'register'])->name('register');
        Route::get('/status', [HelperController::class, 'status'])->name('status');
        Route::get('/dashboard', [HelperController::class, 'dashboard'])->name('dashboard');
    });

    // Modul Admin
    Route::prefix('admin')->name('admin.')->group(function () {
        Route::get('/dashboard', [AdminDashboardController::class, 'index'])->name('dashboard');
        Route::get('/verifications', [AdminVerificationController::class, 'index'])->name('verifications.index');
        Route::post('/verifications/{id}/approve', [AdminVerificationController::class, 'approve'])->name('verifications.approve');
        Route::post('/verifications/{id}/reject', [AdminVerificationController::class, 'reject'])->name('verifications.reject');
    });
});
