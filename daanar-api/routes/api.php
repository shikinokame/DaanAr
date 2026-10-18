<?php

use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LandmarkController;
use App\Http\Controllers\Api\MunicipalityController;
use App\Http\Controllers\Api\TrailController;
use Illuminate\Support\Facades\Route;

// Unversioned aliases requested by specification (/api/auth/*, /api/analytics/*, /api/admin/*)
Route::post('auth/register-mobile', [AuthController::class, 'registerMobile']);
Route::post('analytics/log-event', [AnalyticsController::class, 'logEvent']);
Route::prefix('admin')->group(function () {
    Route::get('reports', [AnalyticsController::class, 'reports']);
    Route::get('users', [AnalyticsController::class, 'users']);
    Route::patch('users/{user}/status', [AnalyticsController::class, 'updateUserStatus']);
});

Route::prefix('v1')->group(function () {

    // ── Auth ────────────────────────────────────────────────────────────────
    Route::prefix('auth')->group(function () {
        Route::post('login', [AuthController::class, 'login']);
        Route::post('register-mobile', [AuthController::class, 'registerMobile']);

        // Requires a valid Sanctum token
        Route::middleware('auth:sanctum')->post('logout', [AuthController::class, 'logout']);
    });

    // ── Analytics & Admin API ───────────────────────────────────────────────
    Route::post('analytics/log-event', [AnalyticsController::class, 'logEvent']);
    Route::prefix('admin')->group(function () {
        Route::get('reports', [AnalyticsController::class, 'reports']);
        Route::get('users', [AnalyticsController::class, 'users']);
        Route::patch('users/{user}/status', [AnalyticsController::class, 'updateUserStatus']);
    });

    // ── Public endpoints (no auth required) ─────────────────────────────────

    // Landmarks — featured must be declared before {landmark} to avoid route clash
    Route::prefix('landmarks')->group(function () {
        Route::get('featured', [LandmarkController::class, 'featured']);
        Route::get('/',        [LandmarkController::class, 'index']);
        Route::get('{landmark}', [LandmarkController::class, 'show']);

        // Log a visit — backwards-compatible wrapper around split analytics
        Route::post('{landmark}/visit', function (
            \Illuminate\Http\Request $request,
            \App\Models\Landmark $landmark
        ) {
            $request->validate([
                'user_id'             => 'nullable|integer',
                'userId'              => 'nullable|integer',
                'action_type'         => 'nullable|string|max:32',
                'actionType'          => 'nullable|string|max:32',
                'verification_method' => 'nullable|string|max:32',
                'verificationMethod'  => 'nullable|string|max:32',
                'user_lat'            => 'nullable|numeric',
                'userLat'             => 'nullable|numeric',
                'user_lng'            => 'nullable|numeric',
                'userLng'             => 'nullable|numeric',
                'device_id'           => 'nullable|string|max:64',
                'source'              => 'nullable|string|max:32',
            ]);

            $userId = $request->input('userId', $request->input('user_id'))
                ?? $request->user('sanctum')?->id;
            $actionType = strtoupper((string) $request->input(
                'actionType',
                $request->input('action_type', 'AR_VIEW')
            ));
            if (! in_array($actionType, \App\Models\LandmarkVisit::ALLOWED_ACTIONS, true)) {
                $actionType = \App\Models\LandmarkVisit::ACTION_AR_VIEW;
            }

            $visit = \App\Models\LandmarkVisit::create([
                'landmark_id'         => $landmark->id,
                'user_id'             => $userId,
                'action_type'         => $actionType,
                'verification_method' => $request->input('verificationMethod', $request->input('verification_method', 'REMOTE')),
                'user_lat'            => $request->input('userLat', $request->input('user_lat')),
                'user_lng'            => $request->input('userLng', $request->input('user_lng')),
                'device_id'           => $request->input('device_id') ?: ($userId ? "user_{$userId}" : null),
                'source'              => $request->input('source', strtolower($actionType)),
                'visited_at'          => now(),
            ]);

            return response()->json([
                'status'      => 'recorded',
                'log_id'      => $visit->id,
                'action_type' => $visit->action_type,
            ], 201);
        });
    });

    // Municipalities
    Route::get('municipalities', [MunicipalityController::class, 'index']);

    // Trails
    Route::get('trails',          [TrailController::class, 'index']);
    Route::get('trails/{trail}',  [TrailController::class, 'show']);

    // ── Internal Media Sync (Protected) ─────────────────────────────────────
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
