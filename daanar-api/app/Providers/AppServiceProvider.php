<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('google-routes', function (Request $request) {
            return [
                Limit::perMinute(12)->by('routes-user:'.$request->user()->id),
                Limit::perMinute(40)->by('routes-ip:'.$request->ip()),
                Limit::perDay(max(1, config('services.google_routes.daily_request_limit')))->by('routes-total'),
            ];
        });
    }
}
