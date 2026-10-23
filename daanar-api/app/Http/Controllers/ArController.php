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

        // Railway terminates TLS at its proxy. Always give external AR viewers
        // HTTPS links in production, even if a forwarded scheme is missing.
        $baseUrl = app()->environment('production')
            ? 'https://' . $request->getHttpHost()
            : $request->getSchemeAndHttpHost();

        // Resolve model URL — use uploaded .glb with Scene Viewer cache-buster
        $modelUrl = $landmark->ar_model_url
            ? $baseUrl . '/storage/' . implode('/', array_map(
                'rawurlencode', explode('/', ltrim($landmark->ar_model_url, '/'))
            )) . '?sv=3'
            : null;

        // Hero image for poster/thumbnail
        $heroUrl = $landmark->hero_image
            ? $baseUrl . '/storage/' . $landmark->hero_image
            : null;

        // NFT marker base path
        $nftBasePath = $hasNftMarker
            ? $baseUrl . '/ar-assets/targets/' . pathinfo($landmark->ar_marker_image, PATHINFO_FILENAME)
            : null;

        return view('ar.landmark', compact(
            'landmark',
            'demoMode',
            'modelUrl',
            'heroUrl',
            'nftBasePath',
        ));
    }
}
