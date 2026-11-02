<?php

use App\Http\Controllers\ArController;
use App\Http\Controllers\LandingController;
use Illuminate\Support\Facades\Route;

// Public landing page
Route::get('/', [LandingController::class, 'index']);

// WebAR landmark page
Route::get('/ar/landmark/{id}', [ArController::class, 'show'])->name('ar.landmark');

// Versioned .glb asset route for external AR viewers
Route::get('/storage/ar-models/{version}/{filename}', function (string $version, string $filename) {
    $safeFile = basename($filename);
    $fullPath = storage_path('app/public/landmarks/models/' . $safeFile);
    abort_unless(is_file($fullPath) && str_ends_with(strtolower($safeFile), '.glb'), 404);

    return response()->file($fullPath, [
        'Content-Type' => 'model/gltf-binary',
        'Cache-Control' => 'public, max-age=86400',
    ]);
})->where('filename', '.*\.glb');
