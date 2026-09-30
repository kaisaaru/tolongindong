<?php

namespace App\Enums;

enum ServiceCategoryCode: string
{
    case FOOD_RUN = 'food_run';
    case DELIVERY = 'delivery';
    case MOVING = 'moving';
    case PERSONAL = 'personal';
    case HOUSEHOLD = 'household';
    case LAUNDRY = 'laundry';

    /**
     * Nama tampilan kategori yang ramah pengguna.
     */
    public function label(): string
    {
        return match ($this) {
            self::FOOD_RUN => 'Food Run',
            self::DELIVERY => 'Delivery',
            self::MOVING => 'Moving',
            self::PERSONAL => 'Personal',
            self::HOUSEHOLD => 'Household',
            self::LAUNDRY => 'Laundry',
        };
    }

    /**
     * Deskripsi singkat fungsi kategori layanan.
     */
    public function description(): string
    {
        return match ($this) {
            self::FOOD_RUN => 'Bantuan pembelian dan pengantaran makanan dengan sistem talangan.',
            self::DELIVERY => 'Pengantaran barang atau dokumen dari titik jemput ke tujuan.',
            self::MOVING => 'Bantuan angkat dan pindahan barang antar lokasi.',
            self::PERSONAL => 'Bantuan tugas personal, antrean, atau keperluan harian umum.',
            self::HOUSEHOLD => 'Pekerjaan rumah tangga ringan di tempat tinggal pemesan.',
            self::LAUNDRY => 'Antar jemput dan penanganan cucian pakaian.',
        };
    }

    /**
     * Konfigurasi atribut baku sesuai dokumen erd_final.md Bagian 2 Poin 8.
     */
    public function config(): array
    {
        return match ($this) {
            self::FOOD_RUN => [
                'name' => 'Food Run',
                'base_fee' => 15000,
                'requires_advance' => true,
                'requires_proof_photo' => true,
                'requires_pickup_photo' => false,
                'requires_pickup_address' => true,
                'requires_destination_address' => true,
                'is_dispute_eligible' => false,
            ],
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
            self::MOVING => [
                'name' => 'Moving',
                'base_fee' => 35000,
                'requires_advance' => false,
                'requires_proof_photo' => false,
                'requires_pickup_photo' => false,
                'requires_pickup_address' => true,
                'requires_destination_address' => true,
                'is_dispute_eligible' => false,
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
            self::LAUNDRY => [
                'name' => 'Laundry',
                'base_fee' => 15000,
                'requires_advance' => true,
                'requires_proof_photo' => true,
                'requires_pickup_photo' => false,
                'requires_pickup_address' => true,
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
