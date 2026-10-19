<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\TrailResource;
use App\Models\Trail;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class TrailController extends Controller
{
    /**
     * GET /api/v1/trails
     * All trails with municipality, ordered landmarks, and precomputed segments.
     */
    public function index(): AnonymousResourceCollection
    {
        $trails = Trail::query()
            ->with(['municipality', 'landmarks.municipality', 'segments'])
            ->withCount('landmarks')
            ->orderByRaw('CASE WHEN municipality_id IS NULL THEN 0 ELSE 1 END')
            ->orderBy('id')
            ->get();

        return TrailResource::collection($trails);
    }

    /**
     * GET /api/v1/trails/{trail}
     * Single trail with its municipality, ordered landmarks, and route segments.
     */
    public function show(Trail $trail): TrailResource
    {
        $trail->load(['municipality', 'landmarks.municipality', 'segments']);

        return new TrailResource($trail);
    }
}
