<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $admin = User::updateOrCreate(
            ['email' => 'admin@admin.com'],
            [
                'full_name' => 'Administrator',
                'phone_number' => '08111111111',
                'password' => Hash::make('password'),
                'is_admin' => true,
                'verification_status' => 'verified',
                'email_verified_at' => now(),
                'phone_verified_at' => now(),
            ]
        );

        Wallet::firstOrCreate(
            ['user_id' => $admin->id],
            [
                'available_balance' => 0,
                'held_balance' => 0,
                'currency' => 'IDR',
            ]
        );
    }
}
