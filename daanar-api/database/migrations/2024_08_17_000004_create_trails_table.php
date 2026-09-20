<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trails', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description');
            $table->foreignId('municipality_id')->constrained('municipalities')->cascadeOnDelete();
            $table->enum('difficulty', ['easy', 'moderate', 'hard']);
            $table->unsignedSmallInteger('estimated_time');
            $table->timestamps();

            $table->index('difficulty');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trails');
    }
};
