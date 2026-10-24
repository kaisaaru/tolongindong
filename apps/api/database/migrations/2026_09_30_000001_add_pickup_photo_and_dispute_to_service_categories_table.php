<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (DEC-10, DEC-24, Turunan SA #10).
     */
    public function up(): void
    {
        Schema::table('service_categories', function (Blueprint $table) {
            $table->boolean('requires_pickup_photo')->default(false)->after('requires_proof_photo');
            $table->boolean('is_dispute_eligible')->default(false)->after('requires_destination_address');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('service_categories', function (Blueprint $table) {
            $table->dropColumn(['requires_pickup_photo', 'is_dispute_eligible']);
        });
    }
};
