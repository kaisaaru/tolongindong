<?php

namespace Tests\Feature;

use App\Enums\HelperAvailability;
use App\Models\Address;
use App\Models\HelperProfile;
use App\Models\ServiceCategory;
use App\Models\User;
use Illuminate\Support\Str;
use Tests\TestCase;

class HelperCatalogTest extends TestCase
{
    private function createHelper(string $name, float $lat, float $lon, int $hourlyRate = 25000, float $rating = 4.5, string $availability = 'available', bool $approved = true): array
    {
        $unique = Str::random(6);

        $user = User::create([
            'full_name' => $name,
            'email' => "helper_{$unique}@example.com",
            'phone_number' => '0819' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
            'verification_status' => $approved ? 'verified' : 'pending',
        ]);

        $profile = HelperProfile::create([
            'user_id' => $user->id,
            'hourly_rate' => $hourlyRate,
            'max_advance_limit' => 100000,
            'is_available' => $availability,
            'rating_average' => $rating,
            'rating_count' => 10,
            'completed_order_count' => 8,
            'approved_at' => $approved ? now() : null,
        ]);

        $address = Address::create([
            'user_id' => $user->id,
            'label' => 'Lokasi Operasional',
            'full_address' => 'Jl. Operasional No. 1',
            'latitude' => $lat,
            'longitude' => $lon,
            'is_primary' => true,
        ]);

        return [$user, $profile, $address];
    }

    /**
     * Test API-HLP-01 & FR-HLP-005, FR-HLP-006: Helper dalam radius 10 km tampil, di luar 10 km diabaikan.
     */
    public function test_client_can_find_active_helpers_within_10km_radius(): void
    {
        $clientUnique = Str::random(6);
        $client = User::create([
            'full_name' => 'Client Pencari',
            'email' => "client_search_{$clientUnique}@example.com",
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);

        // Client di koordinat (-7.750000, 110.370000)
        $clientLat = -7.750000;
        $clientLon = 110.370000;

        // Helper 1: ~1.5 km dari client (-7.760000, 110.375000)
        [$h1User, $h1Profile] = $this->createHelper('Helper Dekat', -7.760000, 110.375000);

        // Helper 2: ~30 km dari client (-7.450000, 110.370000) - Jauh (>10 km)
        [$h2User, $h2Profile] = $this->createHelper('Helper Jauh', -7.450000, 110.370000);

        $response = $this->actingAs($client, 'sanctum')
            ->getJson("/helpers?latitude={$clientLat}&longitude={$clientLon}");

        $response->assertStatus(200)
            ->assertJsonPath('success', true);

        $helpers = $response->json('data.helpers');
        $helperUserIds = collect($helpers)->pluck('user_id')->all();

        // Helper dekat harus masuk, helper jauh harus di-filter (FR-HLP-005)
        $this->assertContains($h1User->id, $helperUserIds);
        $this->assertNotContains($h2User->id, $helperUserIds);

        // Metadata jumlah helper terdekat di radius (FR-HLP-006)
        $this->assertEquals(count($helpers), $response->json('data.total_available_in_radius'));
    }

    /**
     * Test helper berstatus unavailable atau unapproved tidak muncul di pencarian.
     */
    public function test_unavailable_or_unapproved_helpers_are_excluded(): void
    {
        $client = User::create([
            'full_name' => 'Client Filter Status',
            'email' => 'client_' . Str::random(6) . '@example.com',
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);

        // Helper libur / unavailable
        [$hLibur] = $this->createHelper('Helper Libur', -7.752, 110.371, 20000, 5.0, 'unavailable', true);

        // Helper belum di-approve admin
        [$hPending] = $this->createHelper('Helper Pending', -7.753, 110.372, 20000, 5.0, 'available', false);

        $response = $this->actingAs($client, 'sanctum')
            ->getJson('/helpers?latitude=-7.750&longitude=110.370');

        $response->assertStatus(200);
        $helperUserIds = collect($response->json('data.helpers'))->pluck('user_id')->all();

        $this->assertNotContains($hLibur->id, $helperUserIds);
        $this->assertNotContains($hPending->id, $helperUserIds);
    }

    /**
     * Test FR-HLP-003: Filter helper berdasarkan kategori layanan.
     */
    public function test_client_can_filter_helpers_by_category(): void
    {
        $client = User::create([
            'full_name' => 'Client Kategori',
            'email' => 'client_' . Str::random(6) . '@example.com',
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);

        $catFood = ServiceCategory::where('code', 'food_run')->first();
        $catDelivery = ServiceCategory::where('code', 'delivery')->first();

        // Helper A: Kuasai Food Run
        [$hAUser, $hAProfile] = $this->createHelper('Helper Food', -7.752, 110.371);
        $hAProfile->serviceCategories()->sync([$catFood->id]);

        // Helper B: Kuasai Delivery
        [$hBUser, $hBProfile] = $this->createHelper('Helper Delivery', -7.753, 110.372);
        $hBProfile->serviceCategories()->sync([$catDelivery->id]);

        $response = $this->actingAs($client, 'sanctum')
            ->getJson("/helpers?latitude=-7.750&longitude=110.370&category_id={$catFood->id}");

        $response->assertStatus(200);
        $helperUserIds = collect($response->json('data.helpers'))->pluck('user_id')->all();

        $this->assertContains($hAUser->id, $helperUserIds);
        $this->assertNotContains($hBUser->id, $helperUserIds);
    }

    /**
     * Test FR-HLP-004: Pengurutan berdasarkan rating dan tarif.
     */
    public function test_client_can_sort_helpers_by_rating_and_rate(): void
    {
        $client = User::create([
            'full_name' => 'Client Sort',
            'email' => 'client_' . Str::random(6) . '@example.com',
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);

        [$hMurah] = $this->createHelper('Helper Murah', -7.751, 110.371, 15000, 4.0);
        [$hMahal] = $this->createHelper('Helper Mahal Rating Tinggi', -7.752, 110.372, 50000, 5.0);

        // 1. Sort by rate (tarif terendah lebih dulu)
        $resRate = $this->actingAs($client, 'sanctum')
            ->getJson('/helpers?latitude=-7.750&longitude=110.370&sort_by=rate');

        $helpersByRate = $resRate->json('data.helpers');
        $this->assertEquals($hMurah->id, $helpersByRate[0]['user_id']);

        // 2. Sort by rating (rating tertinggi lebih dulu)
        $resRating = $this->actingAs($client, 'sanctum')
            ->getJson('/helpers?latitude=-7.750&longitude=110.370&sort_by=rating');

        $helpersByRating = $resRating->json('data.helpers');
        $this->assertEquals($hMahal->id, $helpersByRating[0]['user_id']);
    }

    /**
     * Test FR-HLP-008 & FR-HLP-009: Helper terverifikasi dapat mengubah status ketersediaan dan tarif.
     */
    public function test_verified_helper_can_update_profile_and_toggle_availability(): void
    {
        [$helperUser, $helperProfile] = $this->createHelper('Helper Toggle', -7.751, 110.371, 20000, 4.8);

        $catLaundry = ServiceCategory::where('code', 'laundry')->first();

        $response = $this->actingAs($helperUser, 'sanctum')
            ->putJson('/helper/profile', [
                'is_available' => 'unavailable',
                'hourly_rate' => 30000,
                'max_advance_limit' => 200000,
                'category_ids' => [$catLaundry->id],
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.is_available', 'unavailable')
            ->assertJsonPath('data.hourly_rate', 30000)
            ->assertJsonPath('data.max_advance_limit', 200000);

        $helperProfile->refresh();
        $this->assertEquals(HelperAvailability::UNAVAILABLE, $helperProfile->is_available);
        $this->assertEquals(30000, $helperProfile->hourly_rate);
        $this->assertEquals(200000, $helperProfile->max_advance_limit);
        $this->assertTrue($helperProfile->serviceCategories->contains('id', $catLaundry->id));
    }

    /**
     * Test pengguna non-helper ditolak saat memanggil PUT /helper/profile.
     */
    public function test_unverified_user_cannot_update_helper_profile(): void
    {
        $regularUser = User::create([
            'full_name' => 'Regular User',
            'email' => 'regular_' . Str::random(6) . '@example.com',
            'phone_number' => '0812' . rand(10000000, 99999999),
            'password' => 'Pass12345!',
        ]);

        $response = $this->actingAs($regularUser, 'sanctum')
            ->putJson('/helper/profile', [
                'is_available' => 'available',
            ]);

        $response->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }
}
