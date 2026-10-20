<?php

namespace App\Repositories\Contracts;

use App\Models\User;
use Illuminate\Http\UploadedFile;

interface HelperRepositoryInterface
{
    /**
     * Mendaftarkan profil helper dan mengunggah berkas identitas.
     */
    public function registerHelper(User $user, array $data, UploadedFile $idCardPhoto, UploadedFile $selfiePhoto): array;

    /**
     * Dapatkan status helper dan verifikasi pengguna.
     */
    public function getHelperStatus(User $user): array;

    /**
     * Dapatkan metrik dashboard untuk helper aktif.
     */
    public function getHelperDashboard(User $user): array;

    /**
     * Cari dan filter helper dalam radius 10 km (API-HLP-01, FR-HLP-002 s/d 006).
     */
    public function findHelpers(array $filters, ?User $client = null): array;

    /**
     * Perbarui profil operasional helper (FR-HLP-008, FR-HLP-009).
     */
    public function updateHelperProfile(User $user, array $data): array;
}
