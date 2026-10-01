<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, 2.1, 5.1).
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number', 50)->unique();
            $table->foreignUuid('client_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('helper_id')->nullable()->constrained('helper_profiles')->nullOnDelete();
            $table->foreignId('category_id')->constrained('service_categories');
            $table->string('booking_type', 20)->default('broadcast');
            $table->string('status', 50)->default('draft');
            $table->text('task_description');
            $table->foreignId('pickup_address_id')->nullable()->constrained('addresses')->nullOnDelete();
            $table->foreignId('destination_address_id')->nullable()->constrained('addresses')->nullOnDelete();

            // Konsep uang & biaya acuan (DEC-14 no 4, DEC-15)
            $table->bigInteger('client_estimated_price')->default(0);
            $table->bigInteger('base_fee')->default(0);
            $table->bigInteger('distance_fee')->default(0);
            $table->bigInteger('service_fee')->default(0);
            $table->bigInteger('total_amount')->default(0);
            $table->bigInteger('voucher_discount')->default(0);
            $table->bigInteger('service_client_charge')->default(0);
            $table->bigInteger('advance_limit')->default(0);
            $table->bigInteger('held_amount')->default(0);
            $table->bigInteger('advance_actual')->default(0);
            $table->bigInteger('helper_payout')->default(0);
            $table->bigInteger('platform_commission')->default(0);
            $table->bigInteger('cancellation_fee')->default(0);

            // Batas waktu dan pelacakan tahapan
            $table->timestamp('offer_window_expires_at')->nullable();
            $table->timestamp('helper_finished_at')->nullable();
            $table->timestamps();

            // Indeks kueri pesanan aktif (05_erd-draft.md Bagian 5.1)
            $table->index(['client_id', 'status'], 'idx_orders_client_status');
            $table->index(['helper_id', 'status'], 'idx_orders_helper_status');
        });

        // Constraint bisnis PostgreSQL (05_erd-draft.md Bagian 5.1)
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE orders ADD CONSTRAINT chk_voucher_cap CHECK (voucher_discount <= total_amount / 10)");
            DB::statement("ALTER TABLE orders ADD CONSTRAINT chk_commission_nonneg CHECK (platform_commission >= 0)");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE orders DROP CONSTRAINT IF EXISTS chk_voucher_cap");
            DB::statement("ALTER TABLE orders DROP CONSTRAINT IF EXISTS chk_commission_nonneg");
        }

        Schema::dropIfExists('orders');
    }
};
