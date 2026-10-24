<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, DEC-10, DEC-20).
     */
    public function up(): void
    {
        Schema::create('disputes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('raised_by_user_id')->constrained('users')->cascadeOnDelete();
            $table->text('reason');
            $table->string('resolution', 50)->default('pending');
            $table->bigInteger('client_refund_amount')->default(0); // Turunan SA #5
            $table->bigInteger('helper_release_amount')->default(0); // Turunan SA #5
            $table->text('admin_note')->nullable();
            $table->foreignUuid('resolved_by_admin_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('disputes');
    }
};
