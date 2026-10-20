<?php

namespace App\Repositories\Contracts;

use App\Models\User;

interface AddressRepositoryInterface
{
    /**
     * Dapatkan semua alamat milik pengguna (FR-PRF-002).
     */
    public function getUserAddresses(User $user): array;

    /**
     * Dapatkan detail satu alamat milik pengguna.
     */
    public function getAddressById(User $user, int $id): array;

    /**
     * Simpan alamat baru dengan batasan maksimal 10 alamat (FR-PRF-002, DEC-14 no 9).
     */
    public function createAddress(User $user, array $data): array;

    /**
     * Perbarui data alamat milik pengguna.
     */
    public function updateAddress(User $user, int $id, array $data): array;

    /**
     * Hapus alamat milik pengguna.
     */
    public function deleteAddress(User $user, int $id): array;

    /**
     * Tetapkan satu alamat sebagai alamat utama (FR-PRF-003).
     */
    public function setPrimaryAddress(User $user, int $id): array;
}
