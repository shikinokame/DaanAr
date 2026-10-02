<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class ResetAdminPassword extends Command
{
    protected $signature   = 'admin:reset-password';
    protected $description = 'Ensure the admin@daanar.ph password is correctly set (called on deploy startup).';

    public function handle(): int
    {
        $updated = DB::table('users')
            ->where('email', 'admin@daanar.ph')
            ->update(['password' => Hash::make('Vinosaurs')]);

        if ($updated) {
            $this->info('Admin password reset successfully.');
        } else {
            $this->warn('admin@daanar.ph user not found — seeder may not have run yet.');
        }

        return self::SUCCESS;
    }
}
