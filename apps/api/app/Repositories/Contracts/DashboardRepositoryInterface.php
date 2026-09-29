<?php

namespace App\Repositories\Contracts;

use App\Models\User;

interface DashboardRepositoryInterface
{
    /**
     * Dapatkan ringkasan dashboard untuk Client.
     */
    public function getClientDashboard(User $user): array;

    /**
     * Dapatkan ringkasan dashboard untuk Admin / Mentor.
     */
    public function getAdminDashboard(): array;
}
