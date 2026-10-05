<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The original migration defined the enum as ['super_admin', 'lgu_editor'],
     * but the application code (User model, Filament resources) uses
     * ['super_admin', 'admin', 'officer'] as actual role values.
     *
     * This migration aligns the DB enum with the application code.
     * Existing 'lgu_editor' rows are remapped to 'officer'.
     */
    public function up(): void
    {
        // Step 1: Temporarily widen to a plain string so we can do the rename safely
        // (MySQL doesn't allow ALTER COLUMN on an ENUM with existing rows that
        //  don't fit the new values in a single step on all versions.)
        DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(20) NOT NULL DEFAULT 'super_admin'");

        // Step 2: Rename legacy 'lgu_editor' → 'officer' to match the code
        DB::table('users')->where('role', 'lgu_editor')->update(['role' => 'officer']);

        // Step 3: Re-apply the ENUM with the correct values used by the application
        DB::statement("ALTER TABLE users MODIFY COLUMN role ENUM('super_admin', 'admin', 'officer') NOT NULL DEFAULT 'officer'");
    }

    public function down(): void
    {
        // Reverse: officer → lgu_editor, drop admin (or widen first)
        DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(20) NOT NULL DEFAULT 'lgu_editor'");
        DB::table('users')->where('role', 'officer')->update(['role' => 'lgu_editor']);
        DB::table('users')->where('role', 'admin')->update(['role' => 'lgu_editor']);
        DB::statement("ALTER TABLE users MODIFY COLUMN role ENUM('super_admin', 'lgu_editor') NOT NULL DEFAULT 'lgu_editor'");
    }
};
