<?php

namespace App\Enums;

enum NotificationType: string
{
    case ORDER_OFFER = 'order_offer';
    case ORDER_STATUS_CHANGE = 'order_status_change';
    case CHAT_MESSAGE = 'chat_message';
    case DISPUTE_UPDATE = 'dispute_update';
    case WALLET_MUTATION = 'wallet_mutation';
    case PROMO = 'promo';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
