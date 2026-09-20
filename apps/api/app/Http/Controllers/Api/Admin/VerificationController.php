<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\VerificationRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VerificationController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected VerificationRepositoryInterface $verificationRepo
    ) {}

    /**
     * Menampilkan daftar pengajuan verifikasi identitas (API-ADM-02).
     */
    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $perPage = (int) $request->query('per_page', 20);

        $verifications = $this->verificationRepo->getVerifications($status, $perPage);

        return $this->successResponse($verifications, 'Daftar pengajuan verifikasi.');
    }

    /**
     * Menyetujui pengajuan verifikasi identitas helper (API-ADM-03, Skenario A.2).
     */
    public function approve(Request $request, string $id): JsonResponse
    {
        $result = $this->verificationRepo->approve($id, $request->user());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Pengajuan verifikasi helper disetujui.');
    }

    /**
     * Menolak pengajuan verifikasi identitas helper (API-ADM-04, Skenario A.1).
     */
    public function reject(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'rejection_reason' => 'required|string|min:5|max:1000',
        ], [
            'rejection_reason.required' => 'Alasan penolakan wajib disertakan.',
            'rejection_reason.min' => 'Alasan penolakan minimal 5 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi penolakan gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->verificationRepo->reject($id, $request->rejection_reason, $request->user());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse(
            $result['data'],
            'Pengajuan verifikasi ditolak. Pengguna dapat mengajukan ulang berkas yang benar.'
        );
    }
}
