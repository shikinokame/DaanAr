<?php

use App\Http\Controllers\ArController;
use App\Http\Controllers\LandingController;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Landing page — serves featured landmarks + municipalities from DB
Route::get('/', [LandingController::class, 'index']);

// WebAR experience — opened via WebView in Flutter
Route::get('/ar/landmark/{id}', [ArController::class, 'show'])->name('ar.landmark');

// Standalone AR test page (no landmark data, just verifies camera + A-Frame work)
Route::get('/ar/test', function () {
    return view('ar.test');
})->name('ar.test');

// TEMP DEBUG — remove after fixing 500 errors
Route::get('/debug/db-check', function () {
    $secret = request('secret');
    if ($secret !== 'daanar2024debug') {
        abort(403);
    }
    $results = [];
    try {
        $results['users']    = DB::select('SELECT id, email, role FROM users');
        $results['tables']   = DB::select("SHOW TABLES");
        $results['role_col'] = DB::select("SHOW COLUMNS FROM users LIKE 'role'");
    } catch (\Throwable $e) {
        $results['db_error'] = $e->getMessage();
    }

    // Test Municipality query (what Filament runs on /admin/municipalities)
    try {
        $results['municipalities'] = DB::select('SELECT id, name FROM municipalities LIMIT 5');
        $results['municipality_count'] = DB::selectOne('SELECT COUNT(*) as cnt FROM municipalities')->cnt;
    } catch (\Throwable $e) {
        $results['municipality_error'] = $e->getMessage();
    }

    // Test Landmark query with municipality join (what Filament runs on /admin/landmarks)
    try {
        $results['landmarks'] = DB::select('SELECT l.id, l.name, m.name as municipality FROM landmarks l LEFT JOIN municipalities m ON l.municipality_id = m.id LIMIT 5');
        $results['landmark_count'] = DB::selectOne('SELECT COUNT(*) as cnt FROM landmarks')->cnt;
    } catch (\Throwable $e) {
        $results['landmark_error'] = $e->getMessage();
    }

    // Test the landmarks_count subquery that MunicipalityResource uses
    try {
        $results['municipalities_with_counts'] = DB::select('SELECT municipalities.id, municipalities.name, (SELECT COUNT(*) FROM landmarks WHERE landmarks.municipality_id = municipalities.id) as landmarks_count FROM municipalities LIMIT 5');
    } catch (\Throwable $e) {
        $results['muni_count_error'] = $e->getMessage();
    }

    // Test trails table
    try {
        $results['trails'] = DB::select('SELECT id, name FROM trails LIMIT 5');
    } catch (\Throwable $e) {
        $results['trails_error'] = $e->getMessage();
    }

    // Check all migration records
    try {
        $results['migrations'] = DB::select("SELECT migration FROM migrations ORDER BY batch DESC LIMIT 20");
    } catch (\Throwable $e) {
        $results['migrations_error'] = $e->getMessage();
    }

    // Check PHP version and extensions
    $results['php_version'] = PHP_VERSION;
    $results['loaded_extensions'] = get_loaded_extensions();

    return response()->json($results, 200, [], JSON_PRETTY_PRINT);
});



