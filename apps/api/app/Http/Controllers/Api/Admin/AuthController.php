<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\AuthRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected AuthRepositoryInterface $authRepo
    ) {}

    /**
     * Autentikasi Login Khusus Administrator (FR-ADM-001, API-ADM-01).
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'identifier' => 'required|string',
            'password' => 'required|string',
        ], [
            'identifier.required' => 'Email atau nomor telepon administrator wajib diisi.',
            'password.required' => 'Kata sandi wajib diisi.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi login admin gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->authRepo->attemptAdminLogin($request->identifier, $request->password);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Login administrator berhasil.');
    }
}
