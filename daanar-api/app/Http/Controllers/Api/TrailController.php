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
     * All trails with municipality and landmark count (no ordered landmarks yet).
     */
    public function index(): AnonymousResourceCollection
    {
        $trails = Trail::query()
            ->with('municipality')
            ->withCount('landmarks')
            ->orderBy('name')
            ->get();

        return TrailResource::collection($trails);
    }

    /**
     * GET /api/v1/trails/{trail}
     * Single trail with its municipality and ordered landmarks.
     */
    public function show(Trail $trail): TrailResource
    {
        $trail->load(['municipality', 'landmarks.municipality']);

        return new TrailResource($trail);
    }
}
