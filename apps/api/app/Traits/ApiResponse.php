<?php

namespace App\Traits;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

trait ApiResponse
{
    /**
     * Return a standardized success JSON response.
     */
    protected function successResponse(mixed $data = null, string $message = 'Operasi berhasil', int $statusCode = 200): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'meta' => [
                'request_id' => 'req_' . Str::random(10),
                'server_time' => now()->toIso8601String(),
            ],
        ], $statusCode);
    }

    /**
     * Return a standardized error JSON response.
     */
    protected function errorResponse(string $message, string $errorCode = 'BAD_REQUEST', mixed $detail = null, int $statusCode = 400): JsonResponse
    {
        $response = [
            'success' => false,
            'message' => $message,
            'error' => [
                'code' => $errorCode,
            ],
            'meta' => [
                'request_id' => 'req_' . Str::random(10),
                'server_time' => now()->toIso8601String(),
            ],
        ];

        if (!is_null($detail)) {
            $response['error']['detail'] = $detail;
        }

        return response()->json($response, $statusCode);
    }
}
