<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\WalletRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class WalletController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected WalletRepositoryInterface $walletRepo
    ) {}

    /**
     * Dapatkan informasi saldo dompet pengguna aktif (API-WLT-01, FR-WLT-001).
     */
    public function show(Request $request): JsonResponse
    {
        $result = $this->walletRepo->getWallet($request->user());

        return $this->successResponse($result['data'], 'Informasi saldo dompet berhasil dimuat.');
    }

    /**
     * Dapatkan riwayat mutasi transaksi dompet (API-WLT-02, FR-WLT-004, FR-WLT-005).
     */
    public function transactions(Request $request): JsonResponse
    {
        $perPage = (int) $request->query('per_page', 20);
        $result = $this->walletRepo->getTransactions($request->user(), $perPage);

        return $this->successResponse($result['data'], 'Riwayat mutasi transaksi dompet.');
    }

    /**
     * Simulasi isi saldo mandiri (API-WLT-03, FR-WLT-006, FR-WLT-009).
     */
    public function topup(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'amount' => 'required|integer|min:10000',
            'idempotency_key' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:255',
        ], [
            'amount.required' => 'Nominal pengisian saldo wajib diisi.',
            'amount.integer' => 'Nominal pengisian saldo harus berupa angka bulat rupiah.',
            'amount.min' => 'Nominal pengisian saldo minimal Rp 10.000.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pengisian saldo gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        // Baca kunci idempotency dari header X-Idempotency-Key atau body
        $idempotencyKey = $request->header('X-Idempotency-Key') ?: $request->input('idempotency_key');

        $result = $this->walletRepo->topup(
            $request->user(),
            (int) $request->input('amount'),
            $idempotencyKey,
            $request->input('description')
        );

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
