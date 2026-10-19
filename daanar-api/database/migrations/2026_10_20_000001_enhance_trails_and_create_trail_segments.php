<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trails', function (Blueprint $table) {
            if (! Schema::hasColumn('trails', 'district')) {
                $table->string('district', 64)->nullable()->after('municipality_id');
            }
            if (! Schema::hasColumn('trails', 'total_distance_metres')) {
                $table->unsignedInteger('total_distance_metres')->nullable()->after('estimated_time');
            }
        });

        try {
            DB::statement('ALTER TABLE trails MODIFY COLUMN municipality_id BIGINT UNSIGNED NULL');
        } catch (\Throwable $e) {
            // Ignore on SQLite
        }

        if (! Schema::hasTable('trail_segments')) {
            Schema::create('trail_segments', function (Blueprint $table) {
                $table->id();
                $table->foreignId('trail_id')->constrained('trails')->cascadeOnDelete();
                $table->unsignedSmallInteger('order')->default(1);
                $table->foreignId('from_landmark_id')->constrained('landmarks')->cascadeOnDelete();
                $table->foreignId('to_landmark_id')->constrained('landmarks')->cascadeOnDelete();
                $table->longText('points_json')->nullable();
                $table->longText('encoded_polyline')->nullable();
                $table->unsignedInteger('distance_m')->default(0);
                $table->unsignedInteger('duration_s')->default(0);
                $table->longText('steps_json')->nullable();
                $table->timestamps();

                $table->index(['trail_id', 'order']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('trail_segments');

        Schema::table('trails', function (Blueprint $table) {
            $cols = array_filter(
                ['district', 'total_distance_metres'],
                fn (string $col) => Schema::hasColumn('trails', $col)
            );
            if (! empty($cols)) {
                $table->dropColumn($cols);
            }
        });
    }
};

