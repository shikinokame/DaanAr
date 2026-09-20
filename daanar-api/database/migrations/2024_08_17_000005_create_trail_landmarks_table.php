<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trail_landmarks', function (Blueprint $table) {
            $table->foreignId('trail_id')->constrained('trails')->cascadeOnDelete();
            $table->foreignId('landmark_id')->constrained('landmarks')->cascadeOnDelete();
            $table->unsignedSmallInteger('order');

            $table->primary(['trail_id', 'landmark_id']);
            $table->unique(['trail_id', 'order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trail_landmarks');
    }
};
