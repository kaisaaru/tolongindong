<?php

namespace App\Http\Middleware;

use App\Traits\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsAdmin
{
    use ApiResponse;
    /**
     * Pastikan pengguna terautentikasi dan memiliki hak akses admin (FR-ADM-002).
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || !$user->is_admin) {
            return $this->errorResponse(
                'Akses ditolak. Endpoint ini hanya dapat diakses oleh administrator.',
                'FORBIDDEN',
                null,
                403
            );
        }

        if ($user->is_suspended) {
            return $this->errorResponse(
                'Akun administrator Anda sedang dinonaktifkan: ' . ($user->suspended_reason ?? 'Pelanggaran ketentuan'),
                'ACCOUNT_SUSPENDED',
                null,
                403
            );
        }

        return $next($request);
    }
}
