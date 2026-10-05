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
    try {
        $users  = DB::select('SELECT id, email, role FROM users');
        $tables = DB::select("SHOW TABLES");
        $roleCol = DB::select("SHOW COLUMNS FROM users LIKE 'role'");
        return response()->json([
            'users'    => $users,
            'tables'   => $tables,
            'role_col' => $roleCol,
        ]);
    } catch (\Throwable $e) {
        return response()->json([
            'error'   => $e->getMessage(),
            'class'   => get_class($e),
            'trace'   => explode("\n", $e->getTraceAsString()),
        ], 500);
    }
});



