<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\VoucherService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VoucherController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected VoucherService $voucherService
    ) {}

    /**
     * Tampilkan voucher aktif milik pengguna (FR-WLT-010).
     */
    public function index(Request $request): JsonResponse
    {
        $result = $this->voucherService->listUserVouchers($request->user());

        return $this->successResponse($result['data'], 'Daftar voucher aktif pengguna.');
    }

    /**
     * Klaim voucher promo menggunakan kode.
     */
    public function claim(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|max:50',
        ], [
            'code.required' => 'Kode voucher wajib diisi.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi kode voucher gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->voucherService->claimVoucher($request->user(), $request->input('code'));

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message'], $result['status_code'] ?? 200);
    }
}
