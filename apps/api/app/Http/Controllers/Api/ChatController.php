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
     * Dapatkan riwayat pesan obrolan pesanan (FR-CHT-002).
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
     * Kirim pesan obrolan baru (FR-CHT-001).
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
