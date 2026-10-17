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
            'category_ids' => 'required|array|min:1|max:3',
            'category_ids.*' => 'required|integer|exists:service_categories,id',
            'hourly_rate' => 'required|integer|min:0',
            'max_advance_limit' => 'nullable|integer|min:0',
            'id_card_photo' => 'required|file|mimes:jpeg,png,jpg|max:5120',
            'selfie_photo' => 'required|file|mimes:jpeg,png,jpg|max:5120',
        ], [
            'category_ids.min' => 'Pilih minimal satu kategori layanan yang Anda kuasai.',
            'category_ids.max' => 'Pilihan kategori layanan maksimal 3 kategori.',
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

    /**
     * Katalog dan pencarian helper dalam radius 10 km (API-HLP-01, FR-HLP-002 s/d 006).
     */
    public function index(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'category_id' => 'nullable|integer|exists:service_categories,id',
            'sort_by' => 'nullable|string|in:distance,rating,rate',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Parameter pencarian tidak valid.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->helperRepo->findHelpers($validator->validated(), $request->user());

        return $this->successResponse($result['data'], 'Daftar helper terdekat berhasil dimuat.');
    }

    /**
     * Perbarui ketersediaan, tarif, dan kategori layanan helper (FR-HLP-008, FR-HLP-009).
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'is_available' => 'nullable|string|in:available,unavailable',
            'hourly_rate' => 'nullable|integer|min:0',
            'max_advance_limit' => 'nullable|integer|min:0',
            'category_ids' => 'nullable|array|min:1|max:3',
            'category_ids.*' => 'required|integer|exists:service_categories,id',
        ], [
            'category_ids.min' => 'Pilih minimal satu kategori layanan.',
            'category_ids.max' => 'Pilihan kategori maksimal 3 kategori.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembaruan profil helper gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->helperRepo->updateHelperProfile($request->user(), $validator->validated());

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
