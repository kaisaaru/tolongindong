<?php

namespace App\Enums;

enum ServiceCategoryCode: string
{
    case DELIVERY = 'delivery';
    case PERSONAL = 'personal';
    case HOUSEHOLD = 'household';

    /**
     * Nama tampilan kategori yang ramah pengguna.
     */
    public function label(): string
    {
        return match ($this) {
            self::DELIVERY => 'Delivery',
            self::PERSONAL => 'Personal',
            self::HOUSEHOLD => 'Household',
        };
    }

    /**
     * Deskripsi singkat fungsi kategori layanan.
     */
    public function description(): string
    {
        return match ($this) {
            self::DELIVERY => 'Pengantaran barang atau dokumen dari titik jemput ke tujuan.',
            self::PERSONAL => 'Bantuan tugas personal, antrean, atau keperluan harian umum.',
            self::HOUSEHOLD => 'Pekerjaan rumah tangga di tempat tinggal pemesan.',
        };
    }

    /**
     * Konfigurasi atribut baku sesuai dokumen erd_final.md Bagian 2 Poin 8.
     */
    public function config(): array
    {
        return match ($this) {
            self::DELIVERY => [
                'name' => 'Delivery',
                'base_fee' => 12000,
                'requires_advance' => false,
                'requires_proof_photo' => true,
                'requires_pickup_photo' => true,
                'requires_pickup_address' => true,
                'requires_destination_address' => true,
                'is_dispute_eligible' => true,
            ],
            self::PERSONAL => [
                'name' => 'Personal',
                'base_fee' => 20000,
                'requires_advance' => false,
                'requires_proof_photo' => false,
                'requires_pickup_photo' => false,
                'requires_pickup_address' => false,
                'requires_destination_address' => true,
                'is_dispute_eligible' => false,
            ],
            self::HOUSEHOLD => [
                'name' => 'Household',
                'base_fee' => 25000,
                'requires_advance' => false,
                'requires_proof_photo' => false,
                'requires_pickup_photo' => false,
                'requires_pickup_address' => false,
                'requires_destination_address' => true,
                'is_dispute_eligible' => false,
            ],
        };
    }

    /**
     * Dapatkan semua nilai string enum.
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
