<?php

namespace App\Services;

use App\Enums\OrderStatus;

class OrderStateMachine
{
    /**
     * Matriks transisi status pesanan yang sah (04_dual-role-transaction-analysis.md).
     */
    private const TRANSITIONS = [
        OrderStatus::DRAFT->value => [
            OrderStatus::SEARCHING->value,
            OrderStatus::AWAITING_QUOTE->value,
        ],
        OrderStatus::SEARCHING->value => [
            OrderStatus::PENDING_CONFIRMATION->value,
            OrderStatus::EXPIRED->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
        ],
        OrderStatus::AWAITING_QUOTE->value => [
            OrderStatus::ACCEPTED->value,
            OrderStatus::EXPIRED->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
        ],
        OrderStatus::PENDING_CONFIRMATION->value => [
            OrderStatus::ACCEPTED->value,
            OrderStatus::SEARCHING->value,
            OrderStatus::EXPIRED->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::ACCEPTED->value => [
            OrderStatus::ON_THE_WAY->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
            OrderStatus::CANCELLED_BY_HELPER->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::ON_THE_WAY->value => [
            OrderStatus::ARRIVED->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
            OrderStatus::CANCELLED_BY_HELPER->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::ARRIVED->value => [
            OrderStatus::IN_PROGRESS->value,
            OrderStatus::CANCELLED_BY_CLIENT->value,
            OrderStatus::CANCELLED_BY_HELPER->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::IN_PROGRESS->value => [
            OrderStatus::PRICE_ADJUSTMENT->value,
            OrderStatus::AWAITING_CONFIRMATION->value,
            OrderStatus::CANCELLED_BY_HELPER->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::PRICE_ADJUSTMENT->value => [
            OrderStatus::IN_PROGRESS->value,
            OrderStatus::CANCELLED_BY_HELPER->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::AWAITING_CONFIRMATION->value => [
            OrderStatus::COMPLETED->value,
            OrderStatus::DISPUTED->value,
            OrderStatus::CANCELLED_BY_ADMIN->value,
        ],
        OrderStatus::DISPUTED->value => [
            OrderStatus::COMPLETED->value,
            OrderStatus::REFUNDED->value,
            OrderStatus::PARTIALLY_REFUNDED->value,
        ],
    ];

    /**
     * Memeriksa apakah perpindahan status dari $from ke $to diizinkan.
     */
    public function canTransition(OrderStatus $from, OrderStatus $to): bool
    {
        $allowed = self::TRANSITIONS[$from->value] ?? [];

        return in_array($to->value, $allowed, true);
    }

    /**
     * Dapatkan daftar status berikutnya yang sah dari status saat ini.
     */
    public function getAllowedTransitions(OrderStatus $current): array
    {
        return self::TRANSITIONS[$current->value] ?? [];
    }
}
