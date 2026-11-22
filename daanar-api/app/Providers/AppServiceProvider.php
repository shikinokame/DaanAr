<?php

namespace App\Providers;

use App\Http\Controllers\LivewireUploadController;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Livewire\Features\SupportFileUploads\FileUploadController;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(FileUploadController::class, LivewireUploadController::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('google-routes', function (Request $request) {
            $userKey = $request->user()?->id ?? $request->header('X-User-Phone') ?? $request->ip();
            return [
                Limit::perMinute(12)->by('routes-user:'.$userKey),
                Limit::perMinute(40)->by('routes-ip:'.$request->ip()),
                Limit::perDay(max(1, config('services.google_routes.daily_request_limit')))->by('routes-total'),
            ];
        });
    }
}
