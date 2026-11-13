<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\GoogleRoutesService;
use App\Services\RoutingUnavailableException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class RoutingController extends Controller
{
    public function compute(Request $request, GoogleRoutesService $routes): JsonResponse
    {
        $data = $request->validate([
            'origin' => 'required|array:latitude,longitude',
            'origin.latitude' => 'required|numeric|between:-90,90',
            'origin.longitude' => 'required|numeric|between:-180,180',
            'destination' => 'required|array:latitude,longitude',
            'destination.latitude' => 'required|numeric|between:-90,90',
            'destination.longitude' => 'required|numeric|between:-180,180',
            'travel_mode' => ['required', Rule::in(['WALK', 'DRIVE', 'BICYCLE'])],
        ]);
        try {
            $result = $routes->compute(array_map('floatval', $data['origin']), array_map('floatval', $data['destination']), $data['travel_mode']);

            return response()->json($result)->header('Cache-Control', 'no-store, private');
        } catch (RoutingUnavailableException $e) {
            return response()->json(['message' => $e->getMessage()], $e->httpStatus)->header('Cache-Control', 'no-store, private');
        }
    }
}
