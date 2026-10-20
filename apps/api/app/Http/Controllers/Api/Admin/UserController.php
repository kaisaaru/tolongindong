<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Services\AdminService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class UserController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected AdminService $adminService
    ) {}

    /**
     * Membekukan (suspend) akun pengguna (API-ADM-08, FR-ADM-009).
     */
    public function suspend(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|min:5|max:1000',
        ], [
            'reason.required' => 'Alasan pembekuan akun wajib disertakan.',
            'reason.min' => 'Alasan pembekuan minimal 5 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi penonaktifan akun gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->adminService->suspendUser($request->user(), $id, $request->input('reason'));

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
     * Mengaktifkan kembali (reactivate) akun yang di-suspend (API-ADM-09, FR-ADM-010).
     */
    public function reactivate(Request $request, string $id): JsonResponse
    {
        $result = $this->adminService->reactivateUser($request->user(), $id);

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
