<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('landmarks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('municipality_id')->constrained('municipalities')->cascadeOnDelete();
            $table->string('name');
            $table->text('description');
            $table->string('short_description');
            $table->enum('category', ['church', 'park', 'historical', 'natural', 'cultural']);
            $table->string('era')->nullable();
            $table->string('address');
            $table->decimal('lat', 10, 8);
            $table->decimal('lng', 11, 8);
            $table->string('hero_image')->nullable();
            $table->string('ar_marker_image')->nullable();
            $table->string('ar_model_url')->nullable();
            $table->string('ar_html_path')->nullable();
            $table->boolean('is_featured')->default(false);
            $table->timestamps();

            $table->index('lat');
            $table->index('lng');
            $table->index('category');
            $table->index('is_featured');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('landmarks');
    }
};
