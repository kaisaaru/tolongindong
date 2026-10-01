<?php

namespace App\Enums;

enum OrderOfferStatus: string
{
    case SUBMITTED = 'submitted';
    case SELECTED = 'selected';
    case CONFIRMED = 'confirmed';
    case NOT_SELECTED = 'not_selected';
    case WITHDRAWN = 'withdrawn';
    case EXPIRED = 'expired';
    case DECLINED = 'declined';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
