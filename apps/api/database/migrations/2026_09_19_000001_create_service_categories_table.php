<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('service_categories', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique(); // varchar biasa sesuai arahan
            $table->string('name');
            $table->bigInteger('base_fee')->default(0);
            $table->boolean('requires_advance')->default(false);
            $table->boolean('requires_proof_photo')->default(false);
            $table->boolean('requires_pickup_address')->default(false);
            $table->boolean('requires_destination_address')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('service_categories');
    }
};
