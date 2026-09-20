<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->enum('role', ['super_admin', 'lgu_editor'])->default('lgu_editor')->after('password');
            $table->foreignId('municipality_id')
                ->nullable()
                ->after('role')
                ->constrained('municipalities')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['municipality_id']);
            $table->dropColumn(['role', 'municipality_id']);
        });
    }
};
