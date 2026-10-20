<?php

namespace App\Enums;

enum OrderStatus: string
{
    case DRAFT = 'draft';
    case SEARCHING = 'searching';
    case AWAITING_QUOTE = 'awaiting_quote';
    case PENDING_CONFIRMATION = 'pending_confirmation';
    case ACCEPTED = 'accepted';
    case ON_THE_WAY = 'on_the_way';
    case ARRIVED = 'arrived';
    case IN_PROGRESS = 'in_progress';
    case PRICE_ADJUSTMENT = 'price_adjustment';
    case AWAITING_CONFIRMATION = 'awaiting_confirmation';
    case COMPLETED = 'completed';
    case CANCELLED_BY_CLIENT = 'cancelled_by_client';
    case CANCELLED_BY_HELPER = 'cancelled_by_helper';
    case CANCELLED_BY_ADMIN = 'cancelled_by_admin';
    case EXPIRED = 'expired';
    case DISPUTED = 'disputed';
    case REFUNDED = 'refunded';
    case PARTIALLY_REFUNDED = 'partially_refunded';

    /**
     * Label status yang ramah pengguna.
     */
    public function label(): string
    {
        return match ($this) {
            self::DRAFT => 'Draf',
            self::SEARCHING => 'Mencari Helper',
            self::AWAITING_QUOTE => 'Menunggu Penawaran Quote',
            self::PENDING_CONFIRMATION => 'Menunggu Konfirmasi Helper',
            self::ACCEPTED => 'Pesanan Diterima',
            self::ON_THE_WAY => 'Menuju Lokasi',
            self::ARRIVED => 'Helper Tiba',
            self::IN_PROGRESS => 'Sedang Dikerjakan',
            self::PRICE_ADJUSTMENT => 'Penyesuaian Biaya Belanja',
            self::AWAITING_CONFIRMATION => 'Menunggu Konfirmasi Selesai',
            self::COMPLETED => 'Selesai',
            self::CANCELLED_BY_CLIENT => 'Dibatalkan oleh Pemesan',
            self::CANCELLED_BY_HELPER => 'Dibatalkan oleh Helper',
            self::CANCELLED_BY_ADMIN => 'Dibatalkan oleh Admin',
            self::EXPIRED => 'Kedaluwarsa',
            self::DISPUTED => 'Dalam Sengketa',
            self::REFUNDED => 'Dana Dikembalikan Penuh',
            self::PARTIALLY_REFUNDED => 'Dana Dikembalikan Sebagian (Split)',
        };
    }

    /**
     * Memeriksa apakah pesanan masih berstatus aktif (sedang berjalan).
     */
    public function isActive(): bool
    {
        return in_array($this, [
            self::PENDING_CONFIRMATION,
            self::ACCEPTED,
            self::ON_THE_WAY,
            self::ARRIVED,
            self::IN_PROGRESS,
            self::PRICE_ADJUSTMENT,
            self::AWAITING_CONFIRMATION,
        ]);
    }

    /**
     * Memeriksa apakah status bersifat terminal (sudah selesai / berakhir).
     */
    public function isTerminal(): bool
    {
        return in_array($this, [
            self::COMPLETED,
            self::CANCELLED_BY_CLIENT,
            self::CANCELLED_BY_HELPER,
            self::CANCELLED_BY_ADMIN,
            self::EXPIRED,
            self::REFUNDED,
            self::PARTIALLY_REFUNDED,
        ]);
    }

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
