<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\AddressRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AddressController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected AddressRepositoryInterface $addressRepo
    ) {}

    /**
     * Tampilkan semua alamat pengguna aktif (FR-PRF-002).
     */
    public function index(Request $request): JsonResponse
    {
        $result = $this->addressRepo->getUserAddresses($request->user());

        return $this->successResponse($result['data'], 'Daftar alamat berhasil dimuat.');
    }

    /**
     * Tampilkan detail satu alamat.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $result = $this->addressRepo->getAddressById($request->user(), $id);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 404
            );
        }

        return $this->successResponse($result['data'], 'Detail alamat berhasil dimuat.');
    }

    /**
     * Tambah alamat baru dengan batas maksimal 10 alamat (FR-PRF-002, DEC-14 no 9).
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'label' => 'required|string|max:100',
            'full_address' => 'required|string|max:1000',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
            'landmark_note' => 'nullable|string|max:255',
            'is_primary' => 'nullable|boolean',
        ], [
            'label.required' => 'Label alamat (misal: Rumah, Kantor) wajib diisi.',
            'full_address.required' => 'Alamat lengkap wajib diisi.',
            'latitude.required' => 'Koordinat latitude wajib ditentukan.',
            'longitude.required' => 'Koordinat longitude wajib ditentukan.',
            'latitude.between' => 'Koordinat latitude harus di antara -90 dan 90 derajat.',
            'longitude.between' => 'Koordinat longitude harus di antara -180 dan 180 derajat.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi penambahan alamat gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->addressRepo->createAddress($request->user(), $validator->validated());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Alamat berhasil ditambahkan.', 201);
    }

    /**
     * Perbarui data alamat milik pengguna.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'label' => 'sometimes|required|string|max:100',
            'full_address' => 'sometimes|required|string|max:1000',
            'latitude' => 'sometimes|required|numeric|between:-90,90',
            'longitude' => 'sometimes|required|numeric|between:-180,180',
            'landmark_note' => 'nullable|string|max:255',
            'is_primary' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi pembaruan alamat gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->addressRepo->updateAddress($request->user(), $id, $validator->validated());

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Alamat berhasil diperbarui.');
    }

    /**
     * Hapus alamat milik pengguna.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $result = $this->addressRepo->deleteAddress($request->user(), $id);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse(null, $result['message']);
    }

    /**
     * Setel alamat sebagai alamat utama (FR-PRF-003).
     */
    public function setPrimary(Request $request, int $id): JsonResponse
    {
        $result = $this->addressRepo->setPrimaryAddress($request->user(), $id);

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], 'Alamat utama berhasil diperbarui.');
    }
}
