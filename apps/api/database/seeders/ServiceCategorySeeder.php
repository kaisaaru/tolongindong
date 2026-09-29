<?php

namespace Database\Seeders;

use App\Enums\ServiceCategoryCode;
use App\Models\ServiceCategory;
use Illuminate\Database\Seeder;

class ServiceCategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        foreach (ServiceCategoryCode::cases() as $category) {
            $config = $category->config();

            ServiceCategory::updateOrCreate(
                ['code' => $category->value],
                [
                    'name' => $config['name'],
                    'base_fee' => $config['base_fee'],
                    'requires_advance' => $config['requires_advance'],
                    'requires_proof_photo' => $config['requires_proof_photo'],
                    'requires_pickup_address' => $config['requires_pickup_address'],
                    'requires_destination_address' => $config['requires_destination_address'],
                ]
            );
        }
    }
}
