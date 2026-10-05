<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Convert the users.role column from a restrictive ENUM to a plain
     * VARCHAR(20). This eliminates MySQL strict-mode errors that occur when
     * Filament/Laravel tries to save or query role values that are valid in
     * PHP code but were never listed in the original ENUM definition.
     *
     * Also normalises any legacy 'lgu_editor' rows to 'officer' so the
     * column values match what User::isLguEditor() actually checks.
     */
    public function up(): void
    {
        // Widen to VARCHAR — works even if a previous migration already did this
        DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(20) NOT NULL DEFAULT 'officer'");

        // Normalise legacy role value
        DB::table('users')->where('role', 'lgu_editor')->update(['role' => 'officer']);
    }

    public function down(): void
    {
        // Best-effort rollback: restore the original enum
        DB::table('users')->where('role', 'officer')->update(['role' => 'lgu_editor']);
        DB::table('users')->where('role', 'admin')->update(['role' => 'lgu_editor']);
        DB::statement("ALTER TABLE users MODIFY COLUMN role ENUM('super_admin','lgu_editor') NOT NULL DEFAULT 'lgu_editor'");
    }
};
