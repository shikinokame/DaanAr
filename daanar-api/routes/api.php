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
});
