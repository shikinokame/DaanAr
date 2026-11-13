<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class PrecomputeTrailRoutes extends Command
{
    protected $signature = 'trails:precompute-routes {--trail=} {--force}';

    protected $description = 'Legacy command: routes are now fetched live from Google Routes';

    public function handle(): int
    {
        $this->info('Google routes are requested live from the current location. No routes were precomputed or stored.');

        return self::SUCCESS;
    }
}
