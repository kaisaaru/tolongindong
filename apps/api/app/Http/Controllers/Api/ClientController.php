<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Repositories\Contracts\DashboardRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ClientController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected DashboardRepositoryInterface $dashboardRepo
    ) {}

    /**
     * Dashboard Client: Ringkasan profil client, wallet, dan statistik platform.
     */
    public function dashboard(Request $request): JsonResponse
    {
        $data = $this->dashboardRepo->getClientDashboard($request->user());

        return $this->successResponse($data, 'Ringkasan dashboard client.');
    }
}
