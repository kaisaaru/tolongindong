<?php

namespace App\Http\Controllers\Api\Admin;

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
     * Daftar seluruh voucher (API-ADM-11).
     */
    public function index(Request $request): JsonResponse
    {
        $result = $this->voucherService->listAdminVouchers($request->all());

        return $this->successResponse($result['data'], 'Daftar voucher platform.');
    }

    /**
     * Admin membuat voucher baru dengan validasi keras (API-ADM-12, FR-ADM-012, DEC-23).
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|string|max:50',
            'discount_type' => 'required|string|in:fixed,percentage',
            'discount_value' => 'required|integer|min:1',
            'max_discount_amount' => 'nullable|integer|min:1',
            'min_order_amount' => 'required|integer|min:0',
            'usage_limit' => 'nullable|integer|min:1',
            'category_id' => 'nullable|integer|exists:service_categories,id',
            'valid_from' => 'required|date',
            'valid_until' => 'required|date',
            'is_active' => 'nullable|boolean',
        ], [
            'code.required' => 'Kode voucher wajib diisi.',
            'discount_type.required' => 'Tipe diskon (fixed/percentage) wajib dipilih.',
            'discount_value.required' => 'Nilai diskon wajib diisi.',
            'min_order_amount.required' => 'Minimal nominal pesanan wajib diisi.',
            'valid_from.required' => 'Tanggal mulai voucher wajib diisi.',
            'valid_until.required' => 'Tanggal berakhir voucher wajib diisi.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembuatan voucher gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->voucherService->createVoucher($request->user(), $validator->validated());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message'], 201);
    }

    /**
     * Admin mengubah atau menonaktifkan voucher (API-ADM-13, DEC-23).
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'is_active' => 'nullable|boolean',
            'usage_limit' => 'nullable|integer|min:1',
            'valid_until' => 'nullable|date',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembaruan voucher gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->voucherService->updateVoucher($request->user(), $id, $validator->validated());

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
