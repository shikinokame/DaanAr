<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add mobile registration fields to `users` and split-analytics columns to `landmark_visits`.
     */
    public function up(): void
    {
        // 1. Update `users` table for mobile phone registration & roles
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'phone_number')) {
                $table->string('phone_number', 32)->nullable()->unique()->after('email');
            }
            if (! Schema::hasColumn('users', 'user_role')) {
                $table->string('user_role', 32)->nullable()->index()->after('role');
            }
            if (! Schema::hasColumn('users', 'status')) {
                $table->string('status', 20)->default('Active')->index()->after('user_role');
            }
        });

        // Allow email & password to be nullable for mobile-only users, and widen `role`
        try {
            DB::statement("ALTER TABLE users MODIFY COLUMN email VARCHAR(255) NULL");
            DB::statement("ALTER TABLE users MODIFY COLUMN password VARCHAR(255) NULL");
            DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(32) NOT NULL DEFAULT 'Tourist'");
        } catch (\Throwable $e) {
            // Ignore if using SQLite in tests where MODIFY COLUMN is unsupported
        }

        // 2. Update `landmark_visits` table for split analytics (PHYSICAL_VISIT, AR_VIEW, MAP_NAV, PAGE_VIEW)
        Schema::table('landmark_visits', function (Blueprint $table) {
            if (! Schema::hasColumn('landmark_visits', 'action_type')) {
                $table->string('action_type', 32)->default('AR_VIEW')->index()->after('user_id');
            }
            if (! Schema::hasColumn('landmark_visits', 'verification_method')) {
                $table->string('verification_method', 32)->nullable()->after('action_type');
            }
            if (! Schema::hasColumn('landmark_visits', 'user_lat')) {
                $table->decimal('user_lat', 10, 8)->nullable()->after('verification_method');
            }
            if (! Schema::hasColumn('landmark_visits', 'user_lng')) {
                $table->decimal('user_lng', 11, 8)->nullable()->after('user_lat');
            }
        });

        // Backfill existing rows based on legacy `source` column
        DB::table('landmark_visits')
            ->where('source', 'geofence')
            ->update([
                'action_type' => 'PHYSICAL_VISIT',
                'verification_method' => 'GPS_GEOFENCE',
            ]);

        DB::table('landmark_visits')
            ->whereIn('source', ['app', 'ar_view'])
            ->update([
                'action_type' => 'AR_VIEW',
                'verification_method' => 'REMOTE',
            ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('landmark_visits', function (Blueprint $table) {
            $cols = array_filter(
                ['action_type', 'verification_method', 'user_lat', 'user_lng'],
                fn ($c) => Schema::hasColumn('landmark_visits', $c)
            );
            if ($cols) {
                $table->dropColumn($cols);
            }
        });

        Schema::table('users', function (Blueprint $table) {
            $cols = array_filter(
                ['phone_number', 'user_role', 'status'],
                fn ($c) => Schema::hasColumn('users', $c)
            );
            if ($cols) {
                $table->dropColumn($cols);
            }
        });
    }
};

