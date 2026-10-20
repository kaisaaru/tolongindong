<?php

namespace App\Enums;

enum PriceAdjustmentStatus: string
{
    case PENDING = 'pending';
    case APPROVED = 'approved';
    case REJECTED = 'rejected';
    case AUTO_APPROVED = 'auto_approved';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
