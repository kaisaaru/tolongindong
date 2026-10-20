<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Dispute;
use App\Repositories\Contracts\OrderRepositoryInterface;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class DisputeController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected OrderRepositoryInterface $orderRepo
    ) {}

    /**
     * Daftar antrean sengketa Delivery (API-ADM-05, FR-ADM-005).
     */
    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status', 'pending');
        $query = Dispute::with(['order.client', 'order.helper.user', 'raisedByUser'])
            ->latest('created_at');

        if ($status !== 'all') {
            $query->where('resolution', $status);
        }

        $disputes = $query->paginate((int) $request->query('per_page', 20));

        return $this->successResponse($disputes, 'Daftar sengketa Delivery.');
    }

    /**
     * Putusan admin terhadap sengketa Delivery (API-ADM-06, FR-ADM-006).
     */
    public function resolve(Request $request, int $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'resolution' => 'required|string|in:favor_client,favor_helper,split',
            'admin_note' => 'required|string|min:5|max:1000',
        ], [
            'resolution.required' => 'Keputusan sengketa wajib dipilih (favor_client, favor_helper, split).',
            'admin_note.required' => 'Catatan dasar pertimbangan keputusan wajib diisi.',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse('Validasi putusan sengketa gagal.', 'VALIDATION_ERROR', $validator->errors(), 422);
        }

        $result = $this->orderRepo->resolveDispute(
            $request->user(),
            $id,
            $request->input('resolution'),
            $request->input('admin_note')
        );

        if (!$result['success']) {
            return $this->errorResponse(
                $result['message'],
                $result['error_code'],
                $result['detail'] ?? null,
                $result['status_code'] ?? 400
            );
        }

        return $this->successResponse($result['data'], $result['message']);
    }
}
