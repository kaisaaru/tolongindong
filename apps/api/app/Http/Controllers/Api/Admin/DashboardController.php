<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\DashboardRepositoryInterface;
use App\Services\AdminService;
use Illuminate\Http\Request;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected DashboardRepositoryInterface $dashboardRepo,
        protected AdminService $adminService
    ) {}

    /**
     * Dashboard Admin: Ringkasan metrik platform dan verifikasi.
     */
    public function index(): JsonResponse
    {
        $metrics = $this->dashboardRepo->getAdminDashboard();

        return $this->successResponse($metrics, 'Ringkasan dashboard admin.');
    }

    /**
     * Ringkasan pendapatan komisi platform (API-ADM-07, FR-ADM-007).
     */
    public function commissionSummary(Request $request): JsonResponse
    {
        $result = $this->adminService->commissionSummary(
            $request->query('start_date'),
            $request->query('end_date')
        );

        return $this->successResponse($result['data'], $result['message']);
    }
}
