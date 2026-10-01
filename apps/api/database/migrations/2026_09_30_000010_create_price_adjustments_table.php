<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, 2.3, 5.1).
     */
    public function up(): void
    {
        Schema::create('price_adjustments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignId('receipt_attachment_id')->nullable()->constrained('order_attachments')->nullOnDelete();
            $table->bigInteger('requested_amount');
            $table->bigInteger('recognized_amount')->default(0); // Turunan SA #2
            $table->bigInteger('additional_hold_amount')->default(0); // Turunan SA #2
            $table->string('approval_status', 50)->default('pending');
            $table->timestamps();
        });

        // Constraint: Hanya satu penyesuaian harga berstatus pending per order (DEC-14 nomor 2)
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("CREATE UNIQUE INDEX uq_price_adjustment_pending ON price_adjustments(order_id) WHERE approval_status = 'pending'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("DROP INDEX IF EXISTS uq_price_adjustment_pending");
        }

        Schema::dropIfExists('price_adjustments');
    }
};
