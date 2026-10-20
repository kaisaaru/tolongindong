<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ChatService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ChatController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected ChatService $chatService
    ) {}

    /**
     * Dapatkan daftar semua ruang obrolan milik pengguna aktif (Inbox).
     */
    public function rooms(Request $request): JsonResponse
    {
        $result = $this->chatService->getUserRooms($request->user());

        return $this->successResponse($result['data'], $result['message']);
    }

    /**
     * Memulai atau membuka ruang obrolan langsung dengan helper (Pre-Order Chat).
     */
    public function startWithHelper(Request $request, string $helperId): JsonResponse
    {
        $result = $this->chatService->getOrCreateRoomWithHelper($request->user(), $helperId);

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
     * Dapatkan riwayat pesan obrolan berdasarkan ID ruang obrolan.
     */
    public function showRoomMessages(Request $request, int $roomId): JsonResponse
    {
        $result = $this->chatService->getRoomMessages($request->user(), $roomId);

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
     * Kirim pesan baru ke ruang obrolan tertentu.
     */
    public function sendMessageToRoom(Request $request, int $roomId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'content' => 'required|string|max:2000',
            'attachment_url' => 'nullable|string|url|max:500',
        ], [
            'content.required' => 'Isi pesan tidak boleh kosong.',
            'content.max' => 'Pesan maksimal 2000 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pesan gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->chatService->sendMessageToRoom(
            $request->user(),
            $roomId,
            $request->input('content'),
            $request->input('attachment_url')
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message'], $result['status_code'] ?? 201);
    }

    /**
     * Dapatkan riwayat pesan obrolan pesanan (FR-CHT-002, kompatibilitas lama).
     */
    public function index(Request $request, int $orderId): JsonResponse
    {
        $result = $this->chatService->getMessages($request->user(), $orderId);

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
     * Kirim pesan obrolan baru pada pesanan (FR-CHT-001, kompatibilitas lama).
     */
    public function store(Request $request, int $orderId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'content' => 'required|string|max:2000',
            'attachment_url' => 'nullable|string|url|max:500',
        ], [
            'content.required' => 'Isi pesan tidak boleh kosong.',
            'content.max' => 'Pesan maksimal 2000 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pesan gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->chatService->sendMessage(
            $request->user(),
            $orderId,
            $request->input('content'),
            $request->input('attachment_url')
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message'], $result['status_code'] ?? 201);
    }
}
