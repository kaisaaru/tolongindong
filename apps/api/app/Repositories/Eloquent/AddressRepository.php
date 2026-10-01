<?php

namespace App\Repositories\Eloquent;

use App\Models\Address;
use App\Models\User;
use App\Repositories\Contracts\AddressRepositoryInterface;
use Illuminate\Support\Facades\DB;

class AddressRepository implements AddressRepositoryInterface
{
    /**
     * Dapatkan semua alamat milik pengguna, alamat utama di urutan teratas.
     */
    public function getUserAddresses(User $user): array
    {
        $addresses = $user->addresses()
            ->orderByDesc('is_primary')
            ->latest('updated_at')
            ->get();

        return [
            'success' => true,
            'data' => $addresses,
        ];
    }

    /**
     * Dapatkan detail satu alamat milik pengguna.
     */
    public function getAddressById(User $user, int $id): array
    {
        $address = $user->addresses()->find($id);

        if (!$address) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Alamat tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        return [
            'success' => true,
            'data' => $address,
        ];
    }

    /**
     * Simpan alamat baru dengan batasan maksimal 10 alamat (FR-PRF-002, DEC-14 no 9).
     */
    public function createAddress(User $user, array $data): array
    {
        $addressCount = $user->addresses()->count();

        // Enforce FR-PRF-002 & DEC-14 no 9
        if ($addressCount >= 10) {
            return [
                'success' => false,
                'error_code' => 'MAX_ADDRESSES_REACHED',
                'message' => 'Anda telah mencapai batas maksimal 10 alamat tersimpan.',
                'detail' => ['current_count' => $addressCount, 'max_limit' => 10],
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($user, $data, $addressCount) {
            // Alamat pertama otomatis menjadi alamat utama (FR-PRF-003)
            $isPrimary = $addressCount === 0 || !empty($data['is_primary']);

            if ($isPrimary && $addressCount > 0) {
                $user->addresses()->where('is_primary', true)->update(['is_primary' => false]);
            }

            $address = $user->addresses()->create([
                'label' => $data['label'],
                'full_address' => $data['full_address'],
                'latitude' => $data['latitude'],
                'longitude' => $data['longitude'],
                'landmark_note' => $data['landmark_note'] ?? null,
                'is_primary' => $isPrimary,
            ]);

            return [
                'success' => true,
                'data' => $address,
                'status_code' => 201,
            ];
        });
    }

    /**
     * Perbarui data alamat milik pengguna.
     */
    public function updateAddress(User $user, int $id, array $data): array
    {
        $address = $user->addresses()->find($id);

        if (!$address) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Alamat tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        return DB::transaction(function () use ($user, $address, $data) {
            $isPrimary = $data['is_primary'] ?? $address->is_primary;

            if ($isPrimary && !$address->is_primary) {
                $user->addresses()->where('id', '!=', $address->id)->where('is_primary', true)->update(['is_primary' => false]);
            }

            $address->update([
                'label' => $data['label'] ?? $address->label,
                'full_address' => $data['full_address'] ?? $address->full_address,
                'latitude' => $data['latitude'] ?? $address->latitude,
                'longitude' => $data['longitude'] ?? $address->longitude,
                'landmark_note' => array_key_exists('landmark_note', $data) ? $data['landmark_note'] : $address->landmark_note,
                'is_primary' => $isPrimary,
            ]);

            return [
                'success' => true,
                'data' => $address->fresh(),
            ];
        });
    }

    /**
     * Hapus alamat milik pengguna.
     */
    public function deleteAddress(User $user, int $id): array
    {
        $address = $user->addresses()->find($id);

        if (!$address) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Alamat tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        return DB::transaction(function () use ($user, $address) {
            $wasPrimary = $address->is_primary;
            $address->delete();

            // Jika alamat yang dihapus adalah alamat utama, promosikan alamat terbaru lainnya (jika ada)
            if ($wasPrimary) {
                $nextPrimary = $user->addresses()->latest('updated_at')->first();
                $nextPrimary?->update(['is_primary' => true]);
            }

            return [
                'success' => true,
                'message' => 'Alamat berhasil dihapus.',
            ];
        });
    }

    /**
     * Tetapkan satu alamat sebagai alamat utama (FR-PRF-003).
     */
    public function setPrimaryAddress(User $user, int $id): array
    {
        $address = $user->addresses()->find($id);

        if (!$address) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Alamat tidak ditemukan atau bukan milik Anda.',
                'status_code' => 404,
            ];
        }

        return DB::transaction(function () use ($user, $address) {
            $user->addresses()->where('id', '!=', $address->id)->where('is_primary', true)->update(['is_primary' => false]);
            $address->update(['is_primary' => true]);

            return [
                'success' => true,
                'data' => $address->fresh(),
            ];
        });
    }
}
