<?php

namespace App\Services;

use App\Enums\AdminActionType;
use App\Enums\DiscountType;
use App\Models\AdminActionLog;
use App\Models\User;
use App\Models\UserVoucher;
use App\Models\Voucher;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class VoucherService
{
    /**
     * Admin membuat voucher baru dengan validasi keras (API-ADM-12, FR-ADM-012, DEC-23).
     */
    public function createVoucher(User $admin, array $data): array
    {
        // 1. Cek duplikasi kode voucher (409 VOUCHER_CODE_EXISTS)
        $code = strtoupper(trim($data['code']));
        if (Voucher::where('code', $code)->exists()) {
            return [
                'success' => false,
                'error_code' => 'VOUCHER_CODE_EXISTS',
                'message' => "Kode voucher '{$code}' sudah digunakan.",
                'status_code' => 409,
            ];
        }

        // 2. Cek rentang tanggal
        $validFrom = Carbon::parse($data['valid_from']);
        $validUntil = Carbon::parse($data['valid_until']);
        if ($validUntil->lt($validFrom)) {
            return [
                'success' => false,
                'error_code' => 'INVALID_DATE_RANGE',
                'message' => 'Tanggal berakhir voucher tidak boleh lebih awal dari tanggal mulai.',
                'status_code' => 422,
            ];
        }

        $type = DiscountType::from($data['discount_type']);
        $val = (int) $data['discount_value'];
        $minOrder = (int) ($data['min_order_amount'] ?? 0);

        // 3. VALIDASI KERAS (DEC-23, T-11)
        if ($type === DiscountType::FIXED) {
            $requiredMin = $val * 10;
            if ($minOrder < $requiredMin) {
                return [
                    'success' => false,
                    'error_code' => 'VOUCHER_EXCEEDS_COMMISSION',
                    'message' => 'Minimal pesanan terlalu kecil untuk diskon ini. Minimal pesanan wajib sekurang-kurangnya 10 kali nilai diskon.',
                    'detail' => [
                        'discount_value' => $val,
                        'min_order_amount' => $minOrder,
                        'required_min_order_amount' => $requiredMin,
                    ],
                    'status_code' => 422,
                ];
            }
        } elseif ($type === DiscountType::PERCENTAGE) {
            if ($val > 10) {
                return [
                    'success' => false,
                    'error_code' => 'VOUCHER_EXCEEDS_COMMISSION',
                    'message' => 'Diskon persentase tidak boleh melebihi 10 persen agar tidak melebihi batas komisi platform.',
                    'detail' => [
                        'discount_value' => $val,
                        'max_percentage' => 10,
                    ],
                    'status_code' => 422,
                ];
            }
        }

        return DB::transaction(function () use ($admin, $data, $code, $type, $val, $minOrder, $validFrom, $validUntil) {
            $voucher = Voucher::create([
                'code' => $code,
                'discount_type' => $type,
                'discount_value' => $val,
                'max_discount_amount' => isset($data['max_discount_amount']) ? (int) $data['max_discount_amount'] : null,
                'min_order_amount' => $minOrder,
                'usage_limit' => isset($data['usage_limit']) ? (int) $data['usage_limit'] : null,
                'category_id' => $data['category_id'] ?? null,
                'is_active' => $data['is_active'] ?? true,
                'valid_from' => $validFrom,
                'valid_until' => $validUntil,
            ]);

            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => AdminActionType::CREATE_VOUCHER,
                'target_entity' => 'vouchers',
                'target_id' => (string) $voucher->id,
                'note' => "Membuat voucher {$voucher->code}",
            ]);

            return [
                'success' => true,
                'data' => $voucher,
                'message' => 'Voucher promo berhasil dibuat.',
                'status_code' => 201,
            ];
        });
    }

    /**
     * Admin mengubah atau menonaktifkan voucher (API-ADM-13, DEC-23).
     */
    public function updateVoucher(User $admin, int $voucherId, array $data): array
    {
        $voucher = Voucher::find($voucherId);

        if (!$voucher) {
            return [
                'success' => false,
                'error_code' => 'NOT_FOUND',
                'message' => 'Voucher tidak ditemukan.',
                'status_code' => 404,
            ];
        }

        return DB::transaction(function () use ($admin, $voucher, $data) {
            $updateData = [];

            if (isset($data['is_active'])) {
                $updateData['is_active'] = (bool) $data['is_active'];
            }
            if (isset($data['usage_limit'])) {
                $updateData['usage_limit'] = (int) $data['usage_limit'];
            }
            if (isset($data['valid_until'])) {
                $updateData['valid_until'] = Carbon::parse($data['valid_until']);
            }

            $voucher->update($updateData);

            $actionType = (isset($data['is_active']) && !$data['is_active'])
                ? AdminActionType::DEACTIVATE_VOUCHER
                : AdminActionType::UPDATE_VOUCHER;

            AdminActionLog::create([
                'admin_user_id' => $admin->id,
                'action_type' => $actionType,
                'target_entity' => 'vouchers',
                'target_id' => (string) $voucher->id,
                'note' => "Memperbarui voucher {$voucher->code}",
            ]);

            return [
                'success' => true,
                'data' => $voucher->fresh(),
                'message' => 'Voucher berhasil diperbarui.',
            ];
        });
    }

    /**
     * Daftar voucher admin (API-ADM-11).
     */
    public function listAdminVouchers(array $filters = []): array
    {
        $vouchers = Voucher::with('serviceCategory')
            ->withCount(['userVouchers', 'userVouchers as used_count' => function ($q) {
                $q->whereNotNull('used_order_id');
            }])
            ->latest('created_at')
            ->paginate($filters['per_page'] ?? 20);

        return [
            'success' => true,
            'data' => $vouchers,
        ];
    }

    /**
     * Daftar voucher aktif yang dimiliki pengguna (FR-WLT-010).
     */
    public function listUserVouchers(User $user): array
    {
        $userVouchers = $user->userVouchers()
            ->with(['voucher.serviceCategory'])
            ->whereNull('used_order_id')
            ->get()
            ->filter(fn ($uv) => $uv->voucher && $uv->voucher->isValidNow())
            ->map(fn ($uv) => [
                'user_voucher_id' => $uv->id,
                'voucher_id' => $uv->voucher->id,
                'code' => $uv->voucher->code,
                'discount_type' => $uv->voucher->discount_type->value,
                'discount_value' => $uv->voucher->discount_value,
                'max_discount_amount' => $uv->voucher->max_discount_amount,
                'min_order_amount' => $uv->voucher->min_order_amount,
                'valid_until' => $uv->voucher->valid_until->toIso8601String(),
                'category' => $uv->voucher->serviceCategory ? [
                    'id' => $uv->voucher->serviceCategory->id,
                    'name' => $uv->voucher->serviceCategory->name,
                ] : null,
            ])
            ->values();

        return [
            'success' => true,
            'data' => $userVouchers,
        ];
    }

    /**
     * Klaim voucher menggunakan kode promo.
     */
    public function claimVoucher(User $user, string $code): array
    {
        $code = strtoupper(trim($code));
        $voucher = Voucher::where('code', $code)->first();

        if (!$voucher || !$voucher->isValidNow()) {
            return [
                'success' => false,
                'error_code' => 'VOUCHER_EXPIRED_OR_INVALID',
                'message' => 'Kode voucher tidak valid atau sudah kedaluwarsa.',
                'status_code' => 422,
            ];
        }

        // Cek kuota pemakaian global
        if ($voucher->usage_limit !== null && $voucher->userVouchers()->count() >= $voucher->usage_limit) {
            return [
                'success' => false,
                'error_code' => 'VOUCHER_USAGE_LIMIT_EXCEEDED',
                'message' => 'Kuota pemakaian voucher ini sudah habis.',
                'status_code' => 422,
            ];
        }

        // Cek apakah pengguna sudah mengklaim voucher ini sebelumnya
        $alreadyClaimed = UserVoucher::where('user_id', $user->id)
            ->where('voucher_id', $voucher->id)
            ->exists();

        if ($alreadyClaimed) {
            return [
                'success' => false,
                'error_code' => 'VOUCHER_ALREADY_CLAIMED',
                'message' => 'Anda sudah mengklaim voucher ini sebelumnya.',
                'status_code' => 422,
            ];
        }

        $userVoucher = UserVoucher::create([
            'user_id' => $user->id,
            'voucher_id' => $voucher->id,
            'discount_applied' => 0,
        ]);

        return [
            'success' => true,
            'data' => [
                'user_voucher_id' => $userVoucher->id,
                'voucher' => $voucher,
            ],
            'message' => "Voucher '{$voucher->code}' berhasil diklaim!",
            'status_code' => 201,
        ];
    }
}
