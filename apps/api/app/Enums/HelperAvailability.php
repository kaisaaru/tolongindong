<?php

namespace App\Enums;

enum HelperAvailability: string
{
    case AVAILABLE = 'available';
    case UNAVAILABLE = 'unavailable';

    /**
     * Dapatkan semua nilai string enum.
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
