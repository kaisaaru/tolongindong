<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, DEC-14 no 6).
     */
    public function up(): void
    {
        Schema::create('user_vouchers', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('voucher_id')->constrained('vouchers')->cascadeOnDelete();
            $table->foreignId('used_order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->bigInteger('discount_applied')->default(0);
            $table->timestamp('used_at')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        // Constraint: Satu voucher per order (DEC-14 nomor 6, 05_erd-draft.md Bagian 5.1)
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("CREATE UNIQUE INDEX uq_user_voucher_order ON user_vouchers(used_order_id) WHERE used_order_id IS NOT NULL");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("DROP INDEX IF EXISTS uq_user_voucher_order");
        }

        Schema::dropIfExists('user_vouchers');
    }
};
