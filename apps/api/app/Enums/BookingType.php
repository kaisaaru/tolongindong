<?php

namespace App\Enums;

enum BookingType: string
{
    case BROADCAST = 'broadcast';
    case DIRECT = 'direct';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
