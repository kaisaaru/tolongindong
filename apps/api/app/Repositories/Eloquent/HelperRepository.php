<?php

namespace App\Repositories\Eloquent;

use App\Enums\HelperAvailability;
use App\Models\HelperProfile;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Repositories\Contracts\HelperRepositoryInterface;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class HelperRepository implements HelperRepositoryInterface
{
    /**
     * Mendaftarkan profil helper dan mengunggah berkas identitas.
     */
    public function registerHelper(User $user, array $data, UploadedFile $idCardPhoto, UploadedFile $selfiePhoto): array
    {
        if ($user->isVerifiedHelper()) {
            return [
                'success' => false,
                'error_code' => 'ALREADY_HELPER',
                'message' => 'Anda sudah terdaftar dan terverifikasi sebagai Helper aktif.',
                'status_code' => 400,
            ];
        }

        $hasPending = $user->verificationRequests()
            ->where('review_status', 'pending')
            ->exists();

        if ($hasPending) {
            return [
                'success' => false,
                'error_code' => 'VERIFICATION_PENDING_EXISTS',
                'message' => 'Pengajuan verifikasi Anda sebelumnya sedang ditinjau oleh Admin. Mohon menunggu hasil peninjauan.',
                'status_code' => 422,
            ];
        }

        $disk = config('filesystems.default', 'r2');
        $folder = "verifications/{$user->id}";
        $timestamp = now()->format('Ymd_His');
        $idCardExt = $idCardPhoto->getClientOriginalExtension() ?: 'jpg';
        $selfieExt = $selfiePhoto->getClientOriginalExtension() ?: 'jpg';

        $idCardPath = $idCardPhoto->storeAs($folder, "id_card_{$timestamp}.{$idCardExt}", $disk);
        $selfiePath = $selfiePhoto->storeAs($folder, "selfie_{$timestamp}.{$selfieExt}", $disk);

        $idCardUrl = Storage::disk($disk)->url($idCardPath);
        $selfieUrl = Storage::disk($disk)->url($selfiePath);

        return DB::transaction(function () use ($user, $data, $idCardUrl, $selfieUrl) {
            $helperProfile = HelperProfile::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'hourly_rate' => $data['hourly_rate'],
                    'max_advance_limit' => $data['max_advance_limit'],
                    'is_available' => HelperAvailability::UNAVAILABLE,
                ]
            );

            $helperProfile->serviceCategories()->sync($data['category_ids']);

            $verificationRequest = VerificationRequest::create([
                'user_id' => $user->id,
                'id_card_url' => $idCardUrl,
                'selfie_url' => $selfieUrl,
                'review_status' => 'pending',
            ]);

            $user->update(['verification_status' => 'pending']);

            return [
                'success' => true,
                'data' => [
                    'verification_id' => $verificationRequest->id,
                    'review_status' => $verificationRequest->review_status,
                    'helper_profile' => [
                        'id' => $helperProfile->id,
                        'hourly_rate' => $helperProfile->hourly_rate,
                        'max_advance_limit' => $helperProfile->max_advance_limit,
                        'categories' => $helperProfile->serviceCategories()->get(['service_categories.id', 'code', 'name']),
                    ],
                ],
            ];
        });
    }

    /**
     * Dapatkan status helper dan verifikasi pengguna.
     */
    public function getHelperStatus(User $user): array
    {
        $user->load(['helperProfile.serviceCategories']);

        $latestVerification = $user->verificationRequests()
            ->latest('created_at')
            ->first();

        return [
            'verification_status' => $user->verification_status,
            'is_verified_helper' => $user->isVerifiedHelper(),
            'latest_verification' => $latestVerification ? [
                'id' => $latestVerification->id,
                'review_status' => $latestVerification->review_status,
                'rejection_reason' => $latestVerification->rejection_reason,
                'reviewed_at' => $latestVerification->reviewed_at?->toIso8601String(),
                'created_at' => $latestVerification->created_at->toIso8601String(),
            ] : null,
            'helper_profile' => $user->helperProfile ? [
                'id' => $user->helperProfile->id,
                'hourly_rate' => $user->helperProfile->hourly_rate,
                'max_advance_limit' => $user->helperProfile->max_advance_limit,
                'is_available' => $user->helperProfile->is_available,
                'rating_average' => $user->helperProfile->rating_average,
                'rating_count' => $user->helperProfile->rating_count,
                'completed_order_count' => $user->helperProfile->completed_order_count,
                'approved_at' => $user->helperProfile->approved_at?->toIso8601String(),
                'categories' => $user->helperProfile->serviceCategories->map(fn ($cat) => [
                    'id' => $cat->id,
                    'code' => $cat->code,
                    'name' => $cat->name,
                ]),
            ] : null,
        ];
    }

    /**
     * Dapatkan metrik dashboard untuk helper.
     */
    public function getHelperDashboard(User $user): array
    {
        $user->load(['helperProfile.serviceCategories', 'wallet']);
        $profile = $user->helperProfile;

        return [
            'is_helper' => $user->isVerifiedHelper(),
            'profile' => $profile ? [
                'hourly_rate' => $profile->hourly_rate,
                'max_advance_limit' => $profile->max_advance_limit,
                'is_available' => $profile->is_available,
                'rating_average' => $profile->rating_average,
                'rating_count' => $profile->rating_count,
                'completed_orders' => $profile->completed_order_count,
                'cancelled_orders' => $profile->cancelled_order_count,
                'categories' => $profile->serviceCategories->pluck('name'),
            ] : null,
            'wallet' => [
                'available_balance' => $user->wallet?->available_balance ?? 0,
                'held_balance' => $user->wallet?->held_balance ?? 0,
                'currency' => $user->wallet?->currency ?? 'IDR',
            ],
        ];
    }

    /**
     * Hitung jarak Haversine (km) antara dua koordinat geografis.
     */
    private function calculateHaversineDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadius * $c, 2);
    }

    /**
     * Cari dan filter helper dalam radius 10 km (API-HLP-01, FR-HLP-002 s/d 006).
     */
    public function findHelpers(array $filters, ?User $client = null): array
    {
        $clientLat = isset($filters['latitude']) ? (float) $filters['latitude'] : ($client?->primaryAddress?->latitude ? (float) $client->primaryAddress->latitude : null);
        $clientLon = isset($filters['longitude']) ? (float) $filters['longitude'] : ($client?->primaryAddress?->longitude ? (float) $client->primaryAddress->longitude : null);

        $query = HelperProfile::with(['user.addresses', 'serviceCategories'])
            ->where('is_available', HelperAvailability::AVAILABLE->value)
            ->whereNotNull('approved_at')
            ->whereHas('user', function ($q) {
                $q->where('is_suspended', false);
            });

        if (!empty($filters['category_id'])) {
            $query->whereHas('serviceCategories', function ($q) use ($filters) {
                $q->where('service_categories.id', $filters['category_id']);
            });
        }

        $helpers = $query->get();
        $sortBy = $filters['sort_by'] ?? 'distance';
        $maxRadiusKm = 10.0;

        $resultList = [];

        foreach ($helpers as $profile) {
            if ($client && $client->id === $profile->user_id) {
                continue;
            }

            $helperAddress = $profile->user->addresses->firstWhere('is_primary', true) 
                ?: $profile->user->addresses->first();

            $distanceKm = null;
            if ($clientLat !== null && $clientLon !== null && $helperAddress) {
                $distanceKm = $this->calculateHaversineDistance(
                    $clientLat,
                    $clientLon,
                    (float) $helperAddress->latitude,
                    (float) $helperAddress->longitude
                );

                if ($distanceKm > $maxRadiusKm) {
                    continue;
                }
            }

            $resultList[] = [
                'id' => $profile->id,
                'user_id' => $profile->user_id,
                'full_name' => $profile->user->full_name,
                'photo_url' => $profile->user->photo_url,
                'rating_average' => (float) $profile->rating_average,
                'rating_count' => (int) $profile->rating_count,
                'completed_order_count' => (int) $profile->completed_order_count,
                'hourly_rate' => (int) $profile->hourly_rate,
                'max_advance_limit' => (int) $profile->max_advance_limit,
                'is_available' => $profile->is_available->value,
                'distance_km' => $distanceKm,
                'categories' => $profile->serviceCategories->map(fn ($cat) => [
                    'id' => $cat->id,
                    'code' => $cat->code,
                    'name' => $cat->name,
                ])->values(),
            ];
        }

        $collection = collect($resultList);

        if ($sortBy === 'rating') {
            $sorted = $collection->sortByDesc('rating_average')->values();
        } elseif ($sortBy === 'rate') {
            $sorted = $collection->sortBy('hourly_rate')->values();
        } else {
            $sorted = $collection->sortBy(function ($item) {
                return $item['distance_km'] ?? 999999;
            })->values();
        }

        return [
            'success' => true,
            'data' => [
                'helpers' => $sorted->all(),
                'total_available_in_radius' => $sorted->count(),
            ],
        ];
    }

    /**
     * Perbarui profil operasional helper (FR-HLP-008, FR-HLP-009).
     */
    public function updateHelperProfile(User $user, array $data): array
    {
        if (!$user->isVerifiedHelper()) {
            return [
                'success' => false,
                'error_code' => 'FORBIDDEN',
                'message' => 'Hanya akun dengan status helper terverifikasi yang dapat mengubah profil operasional.',
                'status_code' => 403,
            ];
        }

        $profile = $user->helperProfile;

        return DB::transaction(function () use ($profile, $data) {
            $updateData = [];

            if (isset($data['is_available'])) {
                $updateData['is_available'] = $data['is_available'];
            }
            if (isset($data['hourly_rate'])) {
                $updateData['hourly_rate'] = (int) $data['hourly_rate'];
            }
            if (isset($data['max_advance_limit'])) {
                $updateData['max_advance_limit'] = (int) $data['max_advance_limit'];
            }

            if (!empty($updateData)) {
                $profile->update($updateData);
            }

            if (isset($data['category_ids'])) {
                $profile->serviceCategories()->sync($data['category_ids']);
            }

            $profile->load('serviceCategories');

            return [
                'success' => true,
                'data' => [
                    'id' => $profile->id,
                    'is_available' => $profile->is_available->value,
                    'hourly_rate' => $profile->hourly_rate,
                    'max_advance_limit' => $profile->max_advance_limit,
                    'categories' => $profile->serviceCategories->map(fn ($cat) => [
                        'id' => $cat->id,
                        'code' => $cat->code,
                        'name' => $cat->name,
                    ]),
                ],
                'message' => 'Profil operasional helper berhasil diperbarui.',
            ];
        });
    }
}
