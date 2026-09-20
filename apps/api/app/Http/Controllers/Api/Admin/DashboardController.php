<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\DashboardRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected DashboardRepositoryInterface $dashboardRepo
    ) {}

    /**
     * Dashboard Admin: Ringkasan metrik platform dan verifikasi.
     */
    public function index(): JsonResponse
    {
        $metrics = $this->dashboardRepo->getAdminDashboard();

        return $this->successResponse($metrics, 'Ringkasan dashboard admin.');
    }
}
