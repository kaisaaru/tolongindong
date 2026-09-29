<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\HelperRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class HelperController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected HelperRepositoryInterface $helperRepo
    ) {}

    /**
     * Mendaftar menjadi Helper & Mengunggah Berkas Identitas.
     */
    public function register(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'category_ids' => 'required|array|min:1|max:6',
            'category_ids.*' => 'required|integer|exists:service_categories,id',
            'hourly_rate' => 'required|integer|min:0',
            'max_advance_limit' => 'required|integer|min:0',
            'id_card_photo' => 'required|file|mimes:jpeg,png,jpg|max:5120',
            'selfie_photo' => 'required|file|mimes:jpeg,png,jpg|max:5120',
        ], [
            'category_ids.min' => 'Pilih minimal satu kategori layanan yang Anda kuasai.',
            'category_ids.max' => 'Pilihan kategori layanan maksimal 6 kategori.',
            'id_card_photo.required' => 'Foto e-KTP wajib diunggah untuk verifikasi identitas.',
            'selfie_photo.required' => 'Foto selfie memegang e-KTP wajib diunggah.',
            'id_card_photo.max' => 'Ukuran file foto e-KTP maksimal 5MB.',
            'selfie_photo.max' => 'Ukuran file foto selfie maksimal 5MB.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pengajuan helper gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->helperRepo->registerHelper(
            $request->user(),
            $validator->validated(),
            $request->file('id_card_photo'),
            $request->file('selfie_photo')
        );

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
            'Pendaftaran helper dan berkas identitas berhasil dikirim. Menunggu peninjauan admin.',
            201
        );
    }

    /**
     * Memeriksa status verifikasi helper terkini.
     */
    public function status(Request $request): JsonResponse
    {
        $status = $this->helperRepo->getHelperStatus($request->user());

        return $this->successResponse($status, 'Status helper pengguna.');
    }

    /**
     * Dashboard Helper: metrik pekerjaan, rating, dan saldo.
     */
    public function dashboard(Request $request): JsonResponse
    {
        $dashboard = $this->helperRepo->getHelperDashboard($request->user());

        return $this->successResponse($dashboard, 'Ringkasan dashboard helper.');
    }
}
