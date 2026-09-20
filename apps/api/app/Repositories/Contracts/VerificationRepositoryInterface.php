<?php

namespace App\Repositories\Contracts;

use App\Models\User;
use Illuminate\Pagination\LengthAwarePaginator;

interface VerificationRepositoryInterface
{
    /**
     * Dapatkan daftar tiket verifikasi dengan paginasi dan filter status.
     */
    public function getVerifications(string $status = 'pending', int $perPage = 20): LengthAwarePaginator;

    /**
     * Setujui tiket verifikasi helper dan aktifkan profilnya.
     */
    public function approve(string $id, ?User $admin = null): array;

    /**
     * Tolak tiket verifikasi helper dengan alasan penolakan.
     */
    public function reject(string $id, string $reason, ?User $admin = null): array;
}
