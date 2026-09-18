<?php

use App\Http\Controllers\Api\V1\AuthController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes - TolonginDong
| Base URL: /api/v1
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {
    Route::prefix('auth')->group(function () {
        // Public Auth Endpoints
        Route::post('/register', [AuthController::class, 'register'])->name('api.v1.auth.register');
        Route::post('/verify-otp', [AuthController::class, 'verifyOtp'])->name('api.v1.auth.verify_otp');
        Route::post('/send-otp', [AuthController::class, 'sendOtp'])->name('api.v1.auth.send_otp');
        Route::post('/login', [AuthController::class, 'login'])->name('api.v1.auth.login');
        Route::post('/google', [AuthController::class, 'google'])->name('api.v1.auth.google');

        // Protected Auth Endpoints (memerlukan token Sanctum)
        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/me', [AuthController::class, 'me'])->name('api.v1.auth.me');
            Route::post('/logout', [AuthController::class, 'logout'])->name('api.v1.auth.logout');
        });
    });
});
