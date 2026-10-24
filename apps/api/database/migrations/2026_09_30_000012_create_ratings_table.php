<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, DEC-09, INV-08).
     */
    public function up(): void
    {
        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('helper_id')->constrained('helper_profiles')->cascadeOnDelete();
            $table->unsignedTinyInteger('score');
            $table->text('review')->nullable();
            $table->timestamp('created_at')->useCurrent();

            // Rating satu arah, satu per order (DEC-09, INV-08, 05_erd-draft.md Bagian 5.1)
            $table->unique('order_id', 'uq_rating_order');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ratings');
    }
};
