<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (05_erd-draft.md Bagian 1, DEC-16, DEC-24).
     */
    public function up(): void
    {
        Schema::create('order_attachments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignUuid('uploader_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('attachment_type', 50);
            $table->string('file_url', 500);
            $table->timestamp('created_at')->useCurrent();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('order_attachments');
    }
};
