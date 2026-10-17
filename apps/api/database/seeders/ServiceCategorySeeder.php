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
                    'requires_pickup_photo' => $config['requires_pickup_photo'],
                    'requires_pickup_address' => $config['requires_pickup_address'],
                    'requires_destination_address' => $config['requires_destination_address'],
                    'is_dispute_eligible' => $config['is_dispute_eligible'],
                ]
            );
        }

        // Hapus kategori yang sudah tidak aktif bila belum memiliki riwayat pesanan
        $removedCategories = ServiceCategory::whereNotIn('code', ServiceCategoryCode::values())->get();
        foreach ($removedCategories as $cat) {
            $hasOrders = \Illuminate\Support\Facades\DB::table('orders')->where('category_id', $cat->id)->exists();
            if (!$hasOrders) {
                \Illuminate\Support\Facades\DB::table('helper_service_category')
                    ->where('service_category_id', $cat->id)
                    ->delete();
                $cat->delete();
            }
        }
    }
}
