<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ServiceCategory;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;

class ServiceCategoryController extends Controller
{
    use ApiResponse;

    /**
     * Dapatkan daftar kategori layanan aktif (FR-HLP-001).
     */
    public function index(): JsonResponse
    {
        $categories = ServiceCategory::whereIn('code', \App\Enums\ServiceCategoryCode::values())
            ->orderBy('id')
            ->get();

        return $this->successResponse($categories, 'Daftar kategori layanan berhasil dimuat.');
    }
}
