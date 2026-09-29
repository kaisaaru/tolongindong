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
}
