<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OrderController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected AdminService $adminService
    ) {}

    /**
     * Admin membatalkan pesanan darurat (API-ADM-10, FR-ADM-011, DEC-22).
     */
    public function cancel(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|min:5|max:1000',
        ], [
            'reason.required' => 'Alasan pembatalan pesanan oleh admin wajib diisi.',
            'reason.min' => 'Alasan pembatalan minimal 5 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembatalan admin gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->adminService->cancelOrder($request->user(), $id, $request->input('reason'));

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
