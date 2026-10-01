<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, DEC-23).
     */
    public function up(): void
    {
        Schema::create('vouchers', function (Blueprint $table) {
            $table->id();
            $table->string('code', 50)->unique();
            $table->string('discount_type', 20)->default('fixed');
            $table->bigInteger('discount_value');
            $table->bigInteger('max_discount_amount')->nullable();
            $table->bigInteger('min_order_amount')->default(0);
            $table->bigInteger('usage_limit')->nullable();
            $table->foreignId('category_id')->nullable()->constrained('service_categories')->nullOnDelete();
            $table->boolean('is_active')->default(true);
            $table->timestamp('valid_from');
            $table->timestamp('valid_until');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('vouchers');
    }
};
