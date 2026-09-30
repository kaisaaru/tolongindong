<?php

namespace App\Repositories\Eloquent;

use App\Enums\HelperAvailability;
use App\Enums\AdminActionType;
use App\Models\AdminActionLog;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Repositories\Contracts\VerificationRepositoryInterface;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;

class VerificationRepository implements VerificationRepositoryInterface
{
    /**
     * Dapatkan daftar tiket verifikasi dengan paginasi dan filter status.
     */
    public function getVerifications(string $status = 'pending', int $perPage = 20): LengthAwarePaginator
    {
        $query = VerificationRequest::with(['user', 'user.helperProfile.serviceCategories'])
            ->latest('created_at');

        if ($status !== 'all') {
            $query->where('review_status', $status);
        }

        return $query->paginate($perPage);
    }

    /**
     * Setujui tiket verifikasi helper dan aktifkan profilnya.
     */
    public function approve(string $id, ?User $admin = null): array
    {
        $verification = VerificationRequest::find($id);

        if (!$verification) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Tiket verifikasi tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if ($verification->review_status !== 'pending') {
            return [
                'success' => false,
                'error_code' => 'ALREADY_PROCESSED',
                'message' => 'Pengajuan ini sudah diproses sebelumnya.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($verification, $admin) {
            $now = now();

            $verification->update([
                'review_status' => 'approved',
                'reviewed_by_admin_id' => $admin?->id,
                'reviewed_at' => $now,
            ]);

            $user = $verification->user;
            $user->update(['verification_status' => 'verified']);

            if ($user->helperProfile) {
                $user->helperProfile->update([
                    'approved_at' => $now,
                    'is_available' => HelperAvailability::AVAILABLE,
                ]);
            }

            if ($admin) {
                AdminActionLog::create([
                    'admin_user_id' => $admin->id,
                    'action_type' => AdminActionType::APPROVE_VERIFICATION,
                    'target_entity' => 'verification_requests',
                    'target_id' => (string) $verification->id,
                    'note' => 'Pengajuan verifikasi helper disetujui.',
                    'created_at' => $now,
                ]);
            }

            return [
                'success' => true,
                'data' => [
                    'verification_id' => $verification->id,
                    'review_status' => 'approved',
                    'user_id' => $user->id,
                    'verification_status' => $user->verification_status,
                    'is_available' => $user->helperProfile?->is_available?->value ?? HelperAvailability::UNAVAILABLE->value,
                ],
            ];
        });
    }

    /**
     * Tolak tiket verifikasi helper dengan alasan penolakan.
     */
    public function reject(string $id, string $reason, ?User $admin = null): array
    {
        $verification = VerificationRequest::find($id);

        if (!$verification) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Tiket verifikasi tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        if ($verification->review_status !== 'pending') {
            return [
                'success' => false,
                'error_code' => 'ALREADY_PROCESSED',
                'message' => 'Pengajuan ini sudah diproses sebelumnya.',
                'status_code' => 422,
            ];
        }

        return DB::transaction(function () use ($verification, $reason, $admin) {
            $now = now();

            $verification->update([
                'review_status' => 'rejected',
                'rejection_reason' => $reason,
                'reviewed_by_admin_id' => $admin?->id,
                'reviewed_at' => $now,
            ]);

            $user = $verification->user;
            $user->update(['verification_status' => 'rejected']);

            if ($user->helperProfile) {
                $user->helperProfile->update([
                    'approved_at' => null,
                    'is_available' => HelperAvailability::UNAVAILABLE,
                ]);
            }

            if ($admin) {
                AdminActionLog::create([
                    'admin_user_id' => $admin->id,
                    'action_type' => AdminActionType::REJECT_VERIFICATION,
                    'target_entity' => 'verification_requests',
                    'target_id' => (string) $verification->id,
                    'note' => $reason,
                    'created_at' => $now,
                ]);
            }

            return [
                'success' => true,
                'data' => [
                    'verification_id' => $verification->id,
                    'review_status' => 'rejected',
                    'rejection_reason' => $verification->rejection_reason,
                    'can_resubmit_immediately' => true,
                ],
            ];
        });
    }
}
