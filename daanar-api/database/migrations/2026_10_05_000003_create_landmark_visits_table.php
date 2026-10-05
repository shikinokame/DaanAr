<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Create landmark_visits table to track how many users visit each landmark
     * in the Flutter AR app. Each row = one visit event.
     */
    public function up(): void
    {
        Schema::create('landmark_visits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('landmark_id')
                  ->constrained()
                  ->onDelete('cascade');
            // Nullable: anonymous users (not logged in) can still generate visits
            $table->foreignId('user_id')
                  ->nullable()
                  ->constrained()
                  ->onDelete('set null');
            // Device identifier for deduplication (optional)
            $table->string('device_id', 64)->nullable()->index();
            // Source: 'map_tap', 'ar_view', 'search', etc.
            $table->string('source', 32)->default('app')->index();
            $table->timestamp('visited_at')->useCurrent();
            $table->timestamps();

            $table->index(['landmark_id', 'visited_at']);
            $table->index(['landmark_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('landmark_visits');
    }
};
