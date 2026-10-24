<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations to enable pre-order chats between Client and Helper.
     */
    public function up(): void
    {
        Schema::table('chat_rooms', function (Blueprint $table) {
            $table->foreignUuid('client_id')->nullable()->after('id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('helper_id')->nullable()->after('client_id')->constrained('helper_profiles')->cascadeOnDelete();
            $table->unsignedBigInteger('order_id')->nullable()->change();
            $table->index(['client_id', 'helper_id']);
        });

        // Backfill client_id and helper_id from orders for existing chat rooms
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("
                UPDATE chat_rooms cr
                SET client_id = o.client_id, helper_id = o.helper_id
                FROM orders o
                WHERE cr.order_id = o.id AND cr.client_id IS NULL
            ");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('chat_rooms', function (Blueprint $table) {
            $table->dropIndex(['client_id', 'helper_id']);
            $table->dropConstrainedForeignId('client_id');
            $table->dropConstrainedForeignId('helper_id');
        });
    }
};
