<?php

namespace Tests\Feature;

use App\Enums\TransactionType;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Str;
use Tests\TestCase;

class WalletApiTest extends TestCase
{
    private function createUser(): User
    {
        $unique = Str::random(6);

        $user = User::create([
            'full_name' => 'Wallet Tester ' . $unique,
            'email' => "wallet_{$unique}@example.com",
            'phone_number' => '0818' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);

        Wallet::create([
            'user_id' => $user->id,
            'available_balance' => 0,
            'held_balance' => 0,
            'currency' => 'IDR',
        ]);

        return $user;
    }

    /**
     * Test API-WLT-01 & FR-WLT-001: Pengguna dapat melihat saldo TD-Wallet miliknya.
     */
    public function test_user_can_view_wallet_balance(): void
    {
        $user = $this->createUser();

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/wallet');

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.available_balance', 0)
            ->assertJsonPath('data.held_balance', 0)
            ->assertJsonPath('data.total_balance', 0)
            ->assertJsonPath('data.currency', 'IDR');
    }

    /**
     * Test API-WLT-03 & FR-WLT-006: Pengisian saldo berhasil dengan nominal valid.
     */
    public function test_user_can_topup_wallet_with_valid_amount(): void
    {
        $user = $this->createUser();
        $amount = 50000;

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/wallet/topup', [
                'amount' => $amount,
                'description' => 'Topup Mandiri Uji Coba',
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.wallet.available_balance', 50000)
            ->assertJsonPath('data.transaction.amount', 50000)
            ->assertJsonPath('data.transaction.transaction_type', TransactionType::TOPUP->value);

        $this->assertDatabaseHas('wallets', [
            'user_id' => $user->id,
            'available_balance' => 50000,
        ]);

        $this->assertDatabaseHas('wallet_transactions', [
            'amount' => 50000,
            'balance_after' => 50000,
            'transaction_type' => TransactionType::TOPUP->value,
        ]);
    }

    /**
     * Test FR-WLT-006: Pengisian saldo ditolak jika nominal kurang dari Rp10.000.
     */
    public function test_topup_fails_below_minimum_amount(): void
    {
        $user = $this->createUser();

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/wallet/topup', [
                'amount' => 5000,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');

        $this->assertDatabaseHas('wallets', [
            'user_id' => $user->id,
            'available_balance' => 0,
        ]);
    }

    /**
     * Test FR-WLT-009 & Invarian INV-04: Request ganda dengan idempotency key tidak menduplikasi saldo.
     */
    public function test_idempotency_key_prevents_duplicate_topup(): void
    {
        $user = $this->createUser();
        $idempotencyKey = 'req_topup_' . Str::random(12);

        // 1. Request Pertama
        $res1 = $this->actingAs($user, 'sanctum')
            ->withHeaders(['X-Idempotency-Key' => $idempotencyKey])
            ->postJson('/wallet/topup', [
                'amount' => 25000,
            ]);

        $res1->assertStatus(201)
            ->assertJsonPath('data.wallet.available_balance', 25000);

        // 2. Request Kedua dengan Key yang Sama (Idempotent Replay)
        $res2 = $this->actingAs($user, 'sanctum')
            ->withHeaders(['X-Idempotency-Key' => $idempotencyKey])
            ->postJson('/wallet/topup', [
                'amount' => 25000,
            ]);

        $res2->assertStatus(200)
            ->assertJsonPath('data.wallet.available_balance', 25000);

        // Saldo tetap 25.000 (tidak menjadi 50.000)
        $this->assertEquals(25000, $user->wallet->fresh()->available_balance);

        // Baris mutasi hanya ada 1
        $this->assertEquals(1, WalletTransaction::where('idempotency_key', $idempotencyKey)->count());
    }

    /**
     * Test API-WLT-02 & FR-WLT-005: Riwayat mutasi transaksi terpaginasi.
     */
    public function test_user_can_view_transaction_history_paginated(): void
    {
        $user = $this->createUser();

        // 2 Kali Topup
        $this->actingAs($user, 'sanctum')->postJson('/wallet/topup', ['amount' => 20000]);
        $this->actingAs($user, 'sanctum')->postJson('/wallet/topup', ['amount' => 30000]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/wallet/transactions?per_page=10');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $transactions = $response->json('data.data');
        $this->assertCount(2, $transactions);
        $this->assertEquals(50000, $transactions[0]['balance_after']); // Transaksi terakhir di posisi awal
        $this->assertEquals(20000, $transactions[1]['balance_after']);
    }

    /**
     * Test akses ditolak jika unauthenticated.
     */
    public function test_unauthenticated_user_cannot_access_wallet(): void
    {
        $response = $this->getJson('/wallet');
        $response->assertStatus(401);

        $responseTopup = $this->postJson('/wallet/topup', ['amount' => 50000]);
        $responseTopup->assertStatus(401);
    }
}
