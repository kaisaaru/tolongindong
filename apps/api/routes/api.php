<?php

use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\Admin\AuthController as AdminAuthController;
use App\Http\Controllers\Api\Admin\DisputeController as AdminDisputeController;
use App\Http\Controllers\Api\Admin\VoucherController as AdminVoucherController;
use App\Http\Controllers\Api\Admin\OrderController as AdminOrderController;
use App\Http\Controllers\Api\Admin\UserController as AdminUserController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Api\VoucherController;
use App\Http\Controllers\Api\Admin\VerificationController as AdminVerificationController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\HelperController;
use App\Http\Controllers\Api\ServiceCategoryController;
use Illuminate\Support\Facades\Route;

// API Routes

// 1. Public Auth & Umum
Route::post('/register', [AuthController::class, 'register'])->name('auth.register');
Route::post('/verify-otp', [AuthController::class, 'verifyOtp'])->name('auth.verify_otp');
Route::post('/send-otp', [AuthController::class, 'sendOtp'])->name('auth.send_otp');
Route::post('/login', [AuthController::class, 'login'])->name('auth.login');
Route::post('/google', [AuthController::class, 'google'])->name('auth.google');

// Pemulihan & Reset Kata Sandi (FR-AUTH-006)
Route::post('/password/forgot', [AuthController::class, 'forgotPassword'])->name('auth.password.forgot');
Route::post('/password/reset', [AuthController::class, 'resetPassword'])->name('auth.password.reset');


// 1B. Public Auth Admin (FR-ADM-001, API-ADM-01)
Route::post('/admin/auth/login', [AdminAuthController::class, 'login'])->name('admin.auth.login');
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

    // Modul Alamat Pengguna (FR-PRF-002, FR-PRF-003)
    Route::prefix('addresses')->name('addresses.')->group(function () {
        Route::get('/', [AddressController::class, 'index'])->name('index');
        Route::post('/', [AddressController::class, 'store'])->name('store');
        Route::get('/{id}', [AddressController::class, 'show'])->name('show');
        Route::put('/{id}', [AddressController::class, 'update'])->name('update');
        Route::delete('/{id}', [AddressController::class, 'destroy'])->name('destroy');
        Route::post('/{id}/primary', [AddressController::class, 'setPrimary'])->name('set_primary');
    });

    // Modul Dompet TD-Wallet (API-WLT-01, API-WLT-02, API-WLT-03)
    Route::prefix('wallet')->name('wallet.')->group(function () {
        Route::get('/', [WalletController::class, 'show'])->name('show');
        Route::get('/transactions', [WalletController::class, 'transactions'])->name('transactions');
        Route::post('/topup', [WalletController::class, 'topup'])->name('topup');
    });

    // Pencarian & Katalog Helper (API-HLP-01, FR-HLP-002 s/d 006)
    Route::get('/helpers', [HelperController::class, 'index'])->name('helpers.index');

    // Modul Siklus Hidup Pesanan & Bidding (API-ORD-01 s/d 09)
    Route::prefix('orders')->name('orders.')->group(function () {
        Route::post('/estimate', [OrderController::class, 'estimate'])->name('estimate');
        Route::post('/', [OrderController::class, 'store'])->name('store');
        Route::get('/', [OrderController::class, 'index'])->name('index');
        Route::get('/{id}', [OrderController::class, 'show'])->name('show');
        Route::post('/{id}/offers', [OrderController::class, 'submitOffer'])->name('offers.submit');
        Route::post('/{id}/offers/{offer_id}/select', [OrderController::class, 'selectOffer'])->name('offers.select');
        Route::post('/{id}/offers/{offer_id}/confirm', [OrderController::class, 'confirmOffer'])->name('offers.confirm');
        Route::post('/{id}/accept', [OrderController::class, 'accept'])->name('accept');
        Route::post('/{id}/reject', [OrderController::class, 'reject'])->name('reject');
        Route::post('/{id}/status', [OrderController::class, 'updateStatus'])->name('status.update');
        Route::post('/{id}/confirm', [OrderController::class, 'confirmCompletion'])->name('confirm');
        Route::post('/{id}/cancel', [OrderController::class, 'cancel'])->name('cancel');
        Route::post('/{id}/adjustments', [OrderController::class, 'uploadAdjustment'])->name('adjustments.upload');
        Route::post('/{id}/adjustments/{adj_id}/respond', [OrderController::class, 'respondAdjustment'])->name('adjustments.respond');
        Route::post('/{id}/disputes', [OrderController::class, 'raiseDispute'])->name('disputes.raise');
        Route::post('/{id}/rating', [OrderController::class, 'submitRating'])->name('rating.submit');
        Route::get('/{id}/messages', [ChatController::class, 'index'])->name('messages.index');
        Route::post('/{id}/messages', [ChatController::class, 'store'])->name('messages.store');
    });

    // Modul Obrolan / Chat Terpadu (Pre-Order Consultation & Active Order)
    Route::prefix('chats')->name('chats.')->group(function () {
        Route::get('/', [ChatController::class, 'rooms'])->name('rooms');
        Route::post('/helpers/{helperId}', [ChatController::class, 'startWithHelper'])->name('start_with_helper');
        Route::get('/rooms/{roomId}/messages', [ChatController::class, 'showRoomMessages'])->name('room_messages');
        Route::post('/rooms/{roomId}/messages', [ChatController::class, 'sendMessageToRoom'])->name('send_room_message');
    });

    // Modul Helper
    Route::prefix('helper')->name('helper.')->group(function () {
        Route::post('/register', [HelperController::class, 'register'])->name('register');
        Route::get('/status', [HelperController::class, 'status'])->name('status');
        Route::get('/dashboard', [HelperController::class, 'dashboard'])->name('dashboard');
        Route::put('/profile', [HelperController::class, 'updateProfile'])->name('profile.update');
    });

    // Modul Voucher Pengguna (FR-WLT-010)
    Route::get('/vouchers', [VoucherController::class, 'index'])->name('vouchers.index');
    Route::post('/vouchers/claim', [VoucherController::class, 'claim'])->name('vouchers.claim');

    // Modul Notifikasi Pengguna (FR-NOT-001 s/d 005)
    Route::get('/notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markAsRead'])->name('notifications.read');
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllAsRead'])->name('notifications.read_all');

    // Modul Admin (FR-ADM-002)
    Route::prefix('admin')->name('admin.')->middleware('admin')->group(function () {
        Route::get('/dashboard', [AdminDashboardController::class, 'index'])->name('dashboard');
        Route::get('/verifications', [AdminVerificationController::class, 'index'])->name('verifications.index');
        Route::post('/verifications/{id}/approve', [AdminVerificationController::class, 'approve'])->name('verifications.approve');
        Route::post('/verifications/{id}/reject', [AdminVerificationController::class, 'reject'])->name('verifications.reject');
        Route::get('/disputes', [AdminDisputeController::class, 'index'])->name('disputes.index');
        Route::post('/disputes/{id}/resolve', [AdminDisputeController::class, 'resolve'])->name('disputes.resolve');
        Route::get('/commission-summary', [AdminDashboardController::class, 'commissionSummary'])->name('commission_summary');
        Route::post('/users/{id}/suspend', [AdminUserController::class, 'suspend'])->name('users.suspend');
        Route::post('/users/{id}/reactivate', [AdminUserController::class, 'reactivate'])->name('users.reactivate');
        Route::post('/orders/{id}/cancel', [AdminOrderController::class, 'cancel'])->name('orders.cancel');
        // Manajemen Voucher Admin (API-ADM-11, API-ADM-12, API-ADM-13, FR-ADM-012)
        Route::get('/vouchers', [AdminVoucherController::class, 'index'])->name('vouchers.index');
        Route::post('/vouchers', [AdminVoucherController::class, 'store'])->name('vouchers.store');
        Route::patch('/vouchers/{id}', [AdminVoucherController::class, 'update'])->name('vouchers.update');
    });
});
