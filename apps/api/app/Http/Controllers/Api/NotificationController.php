<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\NotificationService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected NotificationService $notificationService
    ) {}

    /**
     * Dapatkan daftar notifikasi pengguna (FR-NOT-001, FR-NOT-005).
     */
    public function index(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 20);
        $result = $this->notificationService->listUserNotifications($request->user(), $perPage);

        return $this->successResponse($result['data'], $result['message']);
    }

    /**
     * Tandai notifikasi spesifik sebagai sudah dibaca.
     */
    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $result = $this->notificationService->markAsRead($request->user(), $id);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 404
            );
        }

        return $this->successResponse($result['data'], $result['message']);
    }

    /**
     * Tandai semua notifikasi pengguna sebagai sudah dibaca.
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        $result = $this->notificationService->markAllAsRead($request->user());

        return $this->successResponse($result['data'], $result['message']);
    }
}
