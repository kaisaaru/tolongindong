<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, 4, 5.1).
     */
    public function up(): void
    {
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained('wallets')->cascadeOnDelete();
            $table->unsignedBigInteger('order_id')->nullable(); // Ditautkan ke orders saat modul order dibuat
            $table->string('transaction_type', 50);
            $table->bigInteger('amount');
            $table->bigInteger('balance_after');
            $table->string('idempotency_key', 100)->unique();
            $table->text('description')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['wallet_id', 'created_at']);
        });

        // Constraint saldo tidak boleh negatif (05_erd-draft.md Bagian 5.1)
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE wallets ADD CONSTRAINT chk_wallet_nonneg CHECK (available_balance >= 0 AND held_balance >= 0)");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE wallets DROP CONSTRAINT IF EXISTS chk_wallet_nonneg");
        }

        Schema::dropIfExists('wallet_transactions');
    }
};
