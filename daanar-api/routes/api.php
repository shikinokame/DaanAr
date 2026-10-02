<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LandmarkController;
use App\Http\Controllers\Api\MunicipalityController;
use App\Http\Controllers\Api\TrailController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // ── Auth ──────────────────────────────────────────────────────────────────
    Route::prefix('auth')->group(function () {
        Route::post('login', [AuthController::class, 'login']);

        // Requires a valid Sanctum token
        Route::middleware('auth:sanctum')->post('logout', [AuthController::class, 'logout']);
    });

    // ── Public endpoints (no auth required) ───────────────────────────────────

    // Landmarks — featured must be declared before {landmark} to avoid route clash
    Route::prefix('landmarks')->group(function () {
        Route::get('featured', [LandmarkController::class, 'featured']);
        Route::get('/',        [LandmarkController::class, 'index']);
        Route::get('{landmark}', [LandmarkController::class, 'show']);
    });

    // Municipalities
    Route::get('municipalities', [MunicipalityController::class, 'index']);

    // Trails
    Route::get('trails',          [TrailController::class, 'index']);
    Route::get('trails/{trail}',  [TrailController::class, 'show']);

    // ── Internal Media Sync (Protected) ───────────────────────────────────
    Route::prefix('internal')->group(function () {
        Route::post('sync-media', function (\Illuminate\Http\Request $request) {
            $secret = $request->header('X-Sync-Secret');
            if ($secret !== 'daanar_sync_secret_2026' && $secret !== config('app.key')) {
                abort(403, 'Unauthorized sync request');
            }

            $path = $request->input('path');
            if (! $path || ! $request->hasFile('file')) {
                return response()->json(['error' => 'Missing file or path'], 400);
            }

            $file = $request->file('file');
            $dir = dirname($path);
            $filename = basename($path);

            \Illuminate\Support\Facades\Storage::disk('public')->putFileAs($dir, $file, $filename);

            return response()->json([
                'status' => 'uploaded',
                'path' => $path,
                'size' => \Illuminate\Support\Facades\Storage::disk('public')->size($path),
            ]);
        });

        Route::get('check-media', function (\Illuminate\Http\Request $request) {
            $files = \Illuminate\Support\Facades\Storage::disk('public')->allFiles('landmarks');
            return response()->json([
                'count' => count($files),
                'files' => $files,
            ]);
        });

        Route::post('reseed', function (\Illuminate\Http\Request $request) {
            $secret = $request->header('X-Sync-Secret');
            if ($secret !== 'daanar_sync_secret_2026' && $secret !== config('app.key')) {
                abort(403, 'Unauthorized sync request');
            }

            \Illuminate\Support\Facades\Artisan::call('db:seed', ['--force' => true]);

            return response()->json([
                'status' => 'reseeded',
                'output' => \Illuminate\Support\Facades\Artisan::output(),
            ]);
        });
    });
});

