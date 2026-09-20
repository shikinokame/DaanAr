<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\MunicipalityResource;
use App\Models\Municipality;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class MunicipalityController extends Controller
{
    /**
     * GET /api/v1/municipalities
     * Returns all municipalities with their landmark count.
     */
    public function index(): AnonymousResourceCollection
    {
        $municipalities = Municipality::query()
            ->withCount('landmarks')
            ->orderBy('name')
            ->get();

        return MunicipalityResource::collection($municipalities);
    }
}
