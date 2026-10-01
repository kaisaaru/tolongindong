<?php

namespace App\Enums;

enum DisputeResolution: string
{
    case PENDING = 'pending';
    case FAVOR_CLIENT = 'favor_client';
    case FAVOR_HELPER = 'favor_helper';
    case SPLIT = 'split';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
