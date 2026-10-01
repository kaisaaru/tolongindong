<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Repositories\Contracts\OrderRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OrderController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected OrderRepositoryInterface $orderRepo
    ) {}

    /**
     * Hitung rentang harga acuan sebelum membuat pesanan (API-ORD-01, FR-ORD-002).
     */
    public function estimate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'category_id' => 'required|integer|exists:service_categories,id',
            'pickup_address_id' => 'nullable|integer|exists:addresses,id',
            'destination_address_id' => 'nullable|integer|exists:addresses,id',
            'distance_km' => 'nullable|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi estimasi biaya gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->calculateEstimate($validator->validated());

        return $this->successResponse($result['data'], 'Estimasi acuan biaya berhasil dihitung.');
    }

    /**
     * Buat pesanan baru (broadcast atau direct booking) (API-ORD-02, FR-ORD-001).
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'category_id' => 'required|integer|exists:service_categories,id',
            'booking_type' => 'nullable|string|in:broadcast,direct',
            'helper_id' => 'nullable|string|exists:helper_profiles,id',
            'task_description' => 'required|string|min:5|max:2000',
            'pickup_address_id' => 'nullable|integer|exists:addresses,id',
            'destination_address_id' => 'nullable|integer|exists:addresses,id',
            'client_estimated_price' => 'nullable|integer|min:0',
            'advance_limit' => 'nullable|integer|min:0',
        ], [
            'task_description.required' => 'Deskripsi tugas atau pesanan wajib diisi.',
            'category_id.required' => 'Kategori layanan wajib dipilih.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembuatan pesanan gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->createOrder($request->user(), $validator->validated());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Pesanan berhasil dibuat.', 201);
    }

    /**
     * Dapatkan detail satu pesanan (API-ORD-03, FR-ORD-008).
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $result = $this->orderRepo->getOrderDetails($request->user(), $id);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 404
            );
        }

        return $this->successResponse($result['data'], 'Detail pesanan berhasil dimuat.');
    }

    /**
     * Dapatkan daftar pesanan pengguna.
     */
    public function index(Request $request): JsonResponse
    {
        $result = $this->orderRepo->listOrders($request->user(), $request->all());

        return $this->successResponse($result['data'], 'Daftar pesanan berhasil dimuat.');
    }

    /**
     * Helper mengajukan penawaran harga atau quote (API-ORD-04A, DEC-05, DEC-21).
     */
    public function submitOffer(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'proposed_price' => 'required|integer|min:1000',
            'message' => 'nullable|string|max:500',
        ], [
            'proposed_price.required' => 'Nominal harga tawaran wajib diisi.',
            'proposed_price.min' => 'Nominal penawaran harga minimal Rp 1.000.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi penawaran harga gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->submitOffer(
            $request->user(),
            $id,
            (int) $request->input('proposed_price'),
            $request->input('message')
        );

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
     * Client memilih salah satu tawaran yang masuk (API-ORD-04C, DEC-05).
     */
    public function selectOffer(Request $request, int $id, int $offerId): JsonResponse
    {
        $result = $this->orderRepo->selectOffer($request->user(), $id, $offerId);

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
     * Helper mengonfirmasi kesiapan dalam 60 detik (broadcast) (API-ORD-04D, DEC-21).
     */
    public function confirmOffer(Request $request, int $id, int $offerId): JsonResponse
    {
        $result = $this->orderRepo->confirmOffer($request->user(), $id, $offerId);

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
     * Helper memajukan tahapan progres pekerjaan (API-ORD-05, FR-ORD-009).
     */
    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:' . implode(',', OrderStatus::values()),
        ], [
            'status.required' => 'Status target wajib diisi.',
            'status.in' => 'Status target tidak valid.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi status gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $targetStatus = OrderStatus::from($request->input('status'));
        $result = $this->orderRepo->updateStatus($request->user(), $id, $targetStatus);

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
     * Client mengonfirmasi pekerjaan selesai & settlement dana (API-ORD-08, FR-ORD-010).
     */
    public function confirmCompletion(Request $request, int $id): JsonResponse
    {
        $result = $this->orderRepo->confirmCompletion($request->user(), $id);

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
     * Membatalkan pesanan (API-ORD-09, FR-ORD-011, DEC-19).
     */
    public function cancel(Request $request, int $id): JsonResponse
    {
        $reason = $request->input('reason');
        $result = $this->orderRepo->cancelOrder($request->user(), $id, $reason);

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
     * Helper mengunggah struk talangan belanja (API-ORD-06, FR-ORD-014, FR-ORD-019).
     */
    public function uploadAdjustment(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'requested_amount' => 'required|integer|min:1',
            'receipt_url' => 'nullable|string|url|max:500',
        ], [
            'requested_amount.required' => 'Nominal struk belanja wajib diisi.',
            'requested_amount.min' => 'Nominal struk belanja harus lebih dari 0.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi struk belanja gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->uploadPriceAdjustment(
            $request->user(),
            $id,
            (int) $request->input('requested_amount'),
            $request->input('receipt_url')
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

    /**
     * Client menyetujui atau menolak penyesuaian belanja (API-ORD-07, FR-ORD-014, DEC-20).
     */
    public function respondAdjustment(Request $request, int $id, int $adjustmentId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|string|in:approved,rejected',
        ], [
            'action.required' => 'Aksi persetujuan (approved/rejected) wajib dipilih.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi respons penyesuaian gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->respondPriceAdjustment(
            $request->user(),
            $id,
            $adjustmentId,
            $request->input('action')
        );

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
     * Mengajukan sengketa pesanan Delivery (API-ORD-12, FR-ORD-018, DEC-10).
     */
    public function raiseDispute(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reason' => 'required|string|min:5|max:1000',
        ], [
            'reason.required' => 'Alasan sengketa wajib diisi.',
            'reason.min' => 'Alasan sengketa minimal 5 karakter.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pengajuan sengketa gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->raiseDispute($request->user(), $id, $request->input('reason'));

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
     * Client memberikan penilaian satu arah ke Helper (FR-RTG-001, DEC-09).
     */
    public function submitRating(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'score' => 'required|integer|between:1,5',
            'review' => 'nullable|string|max:1000',
        ], [
            'score.required' => 'Rating bintang 1 sampai 5 wajib diberikan.',
            'score.between' => 'Rating harus bernilai antara 1 sampai 5 bintang.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi penilaian gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->submitRating(
            $request->user(),
            $id,
            (int) $request->input('score'),
            $request->input('review')
        );

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
}
