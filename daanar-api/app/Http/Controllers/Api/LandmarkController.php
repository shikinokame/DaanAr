<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\LandmarkResource;
use App\Models\Landmark;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class LandmarkController extends Controller
{
    /**
     * GET /api/v1/landmarks
     * Paginated list, filterable by ?municipality=dagupan&category=church
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $query = Landmark::query()->with('municipality');

        // Filter by municipality name (case-insensitive partial match)
        if ($request->filled('municipality')) {
            $query->whereHas('municipality', function ($q) use ($request) {
                $q->where('name', 'like', '%' . $request->string('municipality') . '%');
            });
        }

        // Filter by category enum
        if ($request->filled('category')) {
            $query->where('category', $request->string('category'));
        }

        $landmarks = $query->orderBy('name')->paginate(15)->withQueryString();

        return LandmarkResource::collection($landmarks);
    }

    /**
     * GET /api/v1/landmarks/featured
     * Returns all featured landmarks (is_featured = true).
     */
    public function featured(): AnonymousResourceCollection
    {
        $landmarks = Landmark::query()
            ->with('municipality')
            ->where('is_featured', true)
            ->orderBy('name')
            ->get();

        return LandmarkResource::collection($landmarks);
    }

    /**
     * GET /api/v1/landmarks/{id}
     * Single landmark with its municipality.
     */
    public function show(Landmark $landmark): LandmarkResource
    {
        $landmark->load('municipality');

        return new LandmarkResource($landmark);
    }
}
