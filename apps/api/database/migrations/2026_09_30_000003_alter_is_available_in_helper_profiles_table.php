<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations (DEC-16).
     */
    public function up(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available DROP DEFAULT");
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available TYPE VARCHAR(20) USING (CASE WHEN is_available = TRUE THEN 'available' ELSE 'unavailable' END)");
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available SET DEFAULT 'unavailable'");
        } else {
            Schema::table('helper_profiles', function (Blueprint $table) {
                $table->string('is_available', 20)->default('unavailable')->change();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available DROP DEFAULT");
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available TYPE BOOLEAN USING (CASE WHEN is_available = 'available' THEN TRUE ELSE FALSE END)");
            DB::statement("ALTER TABLE helper_profiles ALTER COLUMN is_available SET DEFAULT FALSE");
        } else {
            Schema::table('helper_profiles', function (Blueprint $table) {
                $table->boolean('is_available')->default(false)->change();
            });
        }
    }
};
