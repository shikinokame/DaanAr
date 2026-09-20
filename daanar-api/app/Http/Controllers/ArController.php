<?php

namespace App\Http\Controllers;

use App\Models\Landmark;
use Illuminate\Http\Request;

class ArController extends Controller
{
    /**
     * Serve the WebAR experience page for a given landmark.
     * GET /ar/landmark/{id}
     *
     * Query params:
     *   ?demo=1  → forces HIRO marker demo mode (no NFT files needed)
     */
    public function show(Request $request, int $id)
    {
        $landmark = Landmark::with('municipality')->findOrFail($id);

        // Determine if NFT marker files exist for this landmark
        $hasNftMarker = $landmark->ar_marker_image
            && file_exists(public_path('ar-assets/targets/' . pathinfo($landmark->ar_marker_image, PATHINFO_FILENAME) . '.fset'));

        // Demo mode: forced via query param OR no NFT files available
        $demoMode = $request->boolean('demo') || ! $hasNftMarker;

        // Resolve model URL — use uploaded .glb or fall back to demo cube
        $modelUrl = $landmark->ar_model_url
            ? asset('storage/' . $landmark->ar_model_url)
            : null;

        // NFT marker base path (AR.js needs basename without extension)
        $nftBasePath = $hasNftMarker
            ? asset('ar-assets/targets/' . pathinfo($landmark->ar_marker_image, PATHINFO_FILENAME))
            : null;

        return view('ar.landmark', compact(
            'landmark',
            'demoMode',
            'modelUrl',
            'nftBasePath',
        ));
    }
}
