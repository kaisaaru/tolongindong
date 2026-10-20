<?php

namespace App\Enums;

enum AdminActionType: string
{
    case APPROVE_VERIFICATION = 'approve_verification';
    case REJECT_VERIFICATION = 'reject_verification';
    case RESOLVE_DISPUTE = 'resolve_dispute';
    case SUSPEND_ACCOUNT = 'suspend_account';
    case REACTIVATE_ACCOUNT = 'reactivate_account';
    case CANCEL_ORDER = 'cancel_order';
    case CREATE_VOUCHER = 'create_voucher';
    case UPDATE_VOUCHER = 'update_voucher';
    case DEACTIVATE_VOUCHER = 'deactivate_voucher';

    /**
     * Dapatkan semua nilai string enum.
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
