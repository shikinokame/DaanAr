<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('municipalities', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('province');
            $table->decimal('lat', 10, 8);
            $table->decimal('lng', 11, 8);
            $table->text('description')->nullable();
            $table->timestamps();

            $table->index('lat');
            $table->index('lng');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('municipalities');
    }
};
