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
}
