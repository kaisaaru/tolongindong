<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, 5.1).
     */
    public function up(): void
    {
        Schema::create('order_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('helper_id')->constrained('helper_profiles')->cascadeOnDelete();
            $table->bigInteger('proposed_price');
            $table->text('message')->nullable();
            $table->string('offer_status', 50)->default('submitted');
            $table->timestamp('valid_until')->nullable(); // Batas 300 detik quote direct booking (DEC-21)
            $table->timestamp('confirmation_expires_at')->nullable(); // Batas 60 detik konfirmasi broadcast (DEC-21)
            $table->timestamps();

            // Constraint: satu tawaran per helper per order (05_erd-draft.md Bagian 5.1)
            $table->unique(['order_id', 'helper_id'], 'uq_offer_order_helper');
            $table->index(['helper_id', 'offer_status'], 'idx_order_offers_helper_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('order_offers');
    }
};
