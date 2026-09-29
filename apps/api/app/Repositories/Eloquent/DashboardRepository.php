<?php

namespace App\Repositories\Eloquent;

use App\Models\HelperProfile;
use App\Models\ServiceCategory;
use App\Models\User;
use App\Models\VerificationRequest;
use App\Repositories\Contracts\DashboardRepositoryInterface;

class DashboardRepository implements DashboardRepositoryInterface
{
    /**
     * Dapatkan ringkasan dashboard untuk Client.
     */
    public function getClientDashboard(User $user): array
    {
        $user->load('wallet');

        return [
            'user' => [
                'id' => $user->id,
                'full_name' => $user->full_name,
                'email' => $user->email,
                'phone_number' => $user->phone_number,
                'verification_status' => $user->verification_status,
                'is_verified_helper' => $user->isVerifiedHelper(),
            ],
            'wallet' => [
                'available_balance' => $user->wallet?->available_balance ?? 0,
                'held_balance' => $user->wallet?->held_balance ?? 0,
                'currency' => $user->wallet?->currency ?? 'IDR',
            ],
            'service_categories_count' => ServiceCategory::count(),
            'active_helpers_count' => HelperProfile::where('is_available', true)->whereNotNull('approved_at')->count(),
        ];
    }

    /**
     * Dapatkan ringkasan dashboard untuk Admin / Mentor.
     */
    public function getAdminDashboard(): array
    {
        return [
            'total_users' => User::count(),
            'total_helpers_verified' => HelperProfile::whereNotNull('approved_at')->count(),
            'pending_verifications' => VerificationRequest::where('review_status', 'pending')->count(),
            'service_categories' => ServiceCategory::count(),
        ];
    }
}
