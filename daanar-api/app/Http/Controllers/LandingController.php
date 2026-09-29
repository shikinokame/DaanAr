<?php

namespace App\Http\Controllers;

use App\Models\Landmark;
use App\Models\Municipality;

class LandingController extends Controller
{
    public function index()
    {
        $featured = Landmark::with('municipality')
            ->where('is_featured', true)
            ->orderBy('name')
            ->get();

        $municipalities = Municipality::withCount('landmarks')
            ->orderBy('name')
            ->get();

        return view('welcome', compact('featured', 'municipalities'));
    }
}
