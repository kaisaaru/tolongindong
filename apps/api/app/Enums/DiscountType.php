<?php

namespace App\Enums;

enum DiscountType: string
{
    case FIXED = 'fixed';
    case PERCENTAGE = 'percentage';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
