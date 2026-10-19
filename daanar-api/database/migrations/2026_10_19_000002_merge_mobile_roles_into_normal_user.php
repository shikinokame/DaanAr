<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Merge the Tourist / Student / Educator mobile roles into a single "Normal User" role,
     * since all three share identical features and permissions in the app.
     */
    public function up(): void
    {
        $legacy = ['Tourist', 'Student', 'Educator', 'tourist', 'student', 'educator'];

        DB::table('users')->whereIn('role', $legacy)->update(['role' => 'Normal User']);
        DB::table('users')->whereIn('user_role', $legacy)->update(['user_role' => 'Normal User']);

        try {
            DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(32) NOT NULL DEFAULT 'Normal User'");
        } catch (\Throwable $e) {
            // Ignore on SQLite (tests) where MODIFY COLUMN is unsupported
        }
    }

    /**
     * Original Tourist/Student/Educator split cannot be recovered; fall back to 'Tourist'.
     */
    public function down(): void
    {
        DB::table('users')->where('role', 'Normal User')->update(['role' => 'Tourist']);
        DB::table('users')->where('user_role', 'Normal User')->update(['user_role' => 'Tourist']);

        try {
            DB::statement("ALTER TABLE users MODIFY COLUMN role VARCHAR(32) NOT NULL DEFAULT 'Tourist'");
        } catch (\Throwable $e) {
            //
        }
    }
};
