<?php

use App\Http\Controllers\ArController;
use App\Http\Controllers\LandingController;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;

// Landing page — serves featured landmarks + municipalities from DB
Route::get('/', [LandingController::class, 'index']);

// WebAR experience — opened via WebView in Flutter
Route::get('/ar/landmark/{id}', [ArController::class, 'show'])->name('ar.landmark');

// Standalone AR test page (no landmark data, just verifies camera + A-Frame work)
Route::get('/ar/test', function () {
    return view('ar.test');
})->name('ar.test');

// ── TEMPORARY DEBUG — remove after login is confirmed working ─────────────────
Route::get('/debug/fix-password', function () {
    $user = DB::table('users')->where('email', 'admin@daanar.ph')->first();
    if (! $user) {
        return response()->json(['status' => 'user_not_found']);
    }

    $newHash = Hash::make('Vinosaurs');
    DB::table('users')->where('email', 'admin@daanar.ph')->update(['password' => $newHash]);

    return response()->json([
        'status'          => 'password_reset',
        'email'           => $user->email,
        'old_hash_prefix' => substr($user->password, 0, 20) . '...',
        'new_hash_prefix' => substr($newHash, 0, 20) . '...',
        'verify_new'      => Hash::check('Vinosaurs', $newHash),
    ]);
});

