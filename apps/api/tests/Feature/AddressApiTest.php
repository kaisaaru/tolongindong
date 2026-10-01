<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\User;
use Illuminate\Support\Str;
use Tests\TestCase;

class AddressApiTest extends TestCase
{
    private function createUser(): User
    {
        $unique = Str::random(6);

        return User::create([
            'full_name' => 'Client Tester ' . $unique,
            'email' => "client_{$unique}@example.com",
            'phone_number' => '0817' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => 'verified',
        ]);
    }

    /**
     * Test FR-PRF-002 & FR-PRF-003: Alamat pertama otomatis menjadi alamat utama.
     */
    public function test_user_can_create_address_and_first_address_is_auto_primary(): void
    {
        $user = $this->createUser();

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/addresses', [
                'label' => 'Rumah',
                'full_address' => 'Jl. Kaliurang KM 5, Gang Pandega Marta No. 12, Sleman',
                'latitude' => -7.75543210,
                'longitude' => 110.37891234,
                'landmark_note' => 'Pagar hitam, samping warung makan',
            ]);

        $response->assertStatus(201)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.label', 'Rumah')
            ->assertJsonPath('data.is_primary', true);

        $this->assertDatabaseHas('addresses', [
            'user_id' => $user->id,
            'label' => 'Rumah',
            'is_primary' => true,
        ]);
    }

    /**
     * Test FR-PRF-003: Menambahkan alamat kedua dengan is_primary=true menggantikan primary lama.
     */
    public function test_adding_new_primary_address_unsets_previous_primary(): void
    {
        $user = $this->createUser();

        // Alamat 1
        $this->actingAs($user, 'sanctum')->postJson('/addresses', [
            'label' => 'Rumah',
            'full_address' => 'Alamat Rumah 1',
            'latitude' => -7.75,
            'longitude' => 110.37,
        ]);

        // Alamat 2 dengan is_primary = true
        $res2 = $this->actingAs($user, 'sanctum')->postJson('/addresses', [
            'label' => 'Kantor',
            'full_address' => 'Alamat Kantor 2',
            'latitude' => -7.78,
            'longitude' => 110.39,
            'is_primary' => true,
        ]);

        $res2->assertStatus(201)
            ->assertJsonPath('data.label', 'Kantor')
            ->assertJsonPath('data.is_primary', true);

        $addresses = $user->addresses()->get();
        $this->assertCount(2, $addresses);

        $addr1 = $addresses->firstWhere('label', 'Rumah');
        $addr2 = $addresses->firstWhere('label', 'Kantor');

        $this->assertFalse($addr1->is_primary);
        $this->assertTrue($addr2->is_primary);
    }

    /**
     * Test FR-PRF-002 / DEC-14 no 9: Batas maksimal 10 alamat tersimpan.
     */
    public function test_user_cannot_exceed_max_10_addresses(): void
    {
        $user = $this->createUser();

        // Buat 10 alamat
        for ($i = 1; $i <= 10; $i++) {
            $user->addresses()->create([
                'label' => "Alamat ke-{$i}",
                'full_address' => "Jalan Contoh No. {$i}",
                'latitude' => -7.7 + ($i * 0.001),
                'longitude' => 110.3 + ($i * 0.001),
                'is_primary' => $i === 1,
            ]);
        }

        $this->assertEquals(10, $user->addresses()->count());

        // Percobaan tambah alamat ke-11 via API
        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/addresses', [
                'label' => 'Alamat ke-11',
                'full_address' => 'Jalan Tambahan No. 11',
                'latitude' => -7.72,
                'longitude' => 110.35,
            ]);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'MAX_ADDRESSES_REACHED');

        $this->assertEquals(10, $user->addresses()->count());
    }

    /**
     * Test daftar semua alamat diurutkan dengan alamat utama di posisi pertama.
     */
    public function test_user_can_view_all_addresses_with_primary_on_top(): void
    {
        $user = $this->createUser();

        $user->addresses()->create([
            'label' => 'Kos',
            'full_address' => 'Jl. Kos No 1',
            'latitude' => -7.71,
            'longitude' => 110.31,
            'is_primary' => false,
        ]);

        $user->addresses()->create([
            'label' => 'Rumah Utama',
            'full_address' => 'Jl. Rumah Utama No 2',
            'latitude' => -7.72,
            'longitude' => 110.32,
            'is_primary' => true,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/addresses');

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $data = $response->json('data');
        $this->assertCount(2, $data);
        $this->assertEquals('Rumah Utama', $data[0]['label']);
        $this->assertTrue($data[0]['is_primary']);
    }

    /**
     * Test pembaruan data alamat.
     */
    public function test_user_can_update_address(): void
    {
        $user = $this->createUser();

        $addr = $user->addresses()->create([
            'label' => 'Rumah Lama',
            'full_address' => 'Jl. Lama No. 5',
            'latitude' => -7.70,
            'longitude' => 110.30,
            'is_primary' => true,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson("/addresses/{$addr->id}", [
                'label' => 'Rumah Baru',
                'full_address' => 'Jl. Baru No. 10',
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.label', 'Rumah Baru')
            ->assertJsonPath('data.full_address', 'Jl. Baru No. 10');

        $this->assertDatabaseHas('addresses', [
            'id' => $addr->id,
            'label' => 'Rumah Baru',
        ]);
    }

    /**
     * Test menyetel alamat utama secara eksplisit (POST /addresses/{id}/primary).
     */
    public function test_user_can_set_primary_address(): void
    {
        $user = $this->createUser();

        $addr1 = $user->addresses()->create([
            'label' => 'Rumah 1',
            'full_address' => 'Jl. Satu No. 1',
            'latitude' => -7.71,
            'longitude' => 110.31,
            'is_primary' => true,
        ]);

        $addr2 = $user->addresses()->create([
            'label' => 'Rumah 2',
            'full_address' => 'Jl. Dua No. 2',
            'latitude' => -7.72,
            'longitude' => 110.32,
            'is_primary' => false,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/addresses/{$addr2->id}/primary");

        $response->assertStatus(200)
            ->assertJsonPath('data.is_primary', true);

        $this->assertFalse($addr1->fresh()->is_primary);
        $this->assertTrue($addr2->fresh()->is_primary);
    }

    /**
     * Test pengguna tidak dapat mengakses atau memodifikasi alamat orang lain.
     */
    public function test_user_cannot_access_or_modify_other_user_address(): void
    {
        $user1 = $this->createUser();
        $user2 = $this->createUser();

        $addr1 = $user1->addresses()->create([
            'label' => 'Rahasia User 1',
            'full_address' => 'Jl. Rahasia',
            'latitude' => -7.71,
            'longitude' => 110.31,
            'is_primary' => true,
        ]);

        // User 2 mencoba get alamat User 1
        $getRes = $this->actingAs($user2, 'sanctum')
            ->getJson("/addresses/{$addr1->id}");

        $getRes->assertStatus(404)
            ->assertJsonPath('error.code', 'NOT_FOUND');

        // User 2 mencoba put alamat User 1
        $putRes = $this->actingAs($user2, 'sanctum')
            ->putJson("/addresses/{$addr1->id}", ['label' => 'Dibajak']);

        $putRes->assertStatus(404);

        // User 2 mencoba delete alamat User 1
        $delRes = $this->actingAs($user2, 'sanctum')
            ->deleteJson("/addresses/{$addr1->id}");

        $delRes->assertStatus(404);
    }

    /**
     * Test menghapus alamat utama mempromosikan alamat berikutnya menjadi utama.
     */
    public function test_deleting_primary_address_promotes_next_address(): void
    {
        $user = $this->createUser();

        $addr1 = $user->addresses()->create([
            'label' => 'Utama Mau Dihapus',
            'full_address' => 'Jl. Mau Dihapus',
            'latitude' => -7.71,
            'longitude' => 110.31,
            'is_primary' => true,
        ]);

        $addr2 = $user->addresses()->create([
            'label' => 'Cadangan Jadi Utama',
            'full_address' => 'Jl. Cadangan',
            'latitude' => -7.72,
            'longitude' => 110.32,
            'is_primary' => false,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->deleteJson("/addresses/{$addr1->id}");

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $this->assertDatabaseMissing('addresses', ['id' => $addr1->id]);
        $this->assertTrue($addr2->fresh()->is_primary);
    }
}
