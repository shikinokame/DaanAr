<?php

use App\Http\Controllers\ArController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/admin/login');
});

// WebAR experience — opened via WebView in Flutter
Route::get('/ar/landmark/{id}', [ArController::class, 'show'])->name('ar.landmark');

// Standalone AR test page (no landmark data, just verifies camera + A-Frame work)
Route::get('/ar/test', function () {
    return view('ar.test');
})->name('ar.test');
