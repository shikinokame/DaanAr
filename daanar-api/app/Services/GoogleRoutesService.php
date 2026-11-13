<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GoogleRoutesService
{
    public function compute(array $origin, array $destination, string $mode): array
    {
        $key = config('services.google_routes.key');
        if (! $key) {
            throw new RoutingUnavailableException('Directions are not available yet. Please try again later.', 503);
        }
        try {
            $response = Http::connectTimeout(5)->timeout(15)->withHeaders([
                'X-Goog-Api-Key' => $key,
                'X-Goog-FieldMask' => implode(',', [
                    'routes.distanceMeters', 'routes.duration', 'routes.polyline', 'routes.warnings',
                    'routes.legs.steps.distanceMeters', 'routes.legs.steps.staticDuration',
                    'routes.legs.steps.startLocation', 'routes.legs.steps.endLocation',
                    'routes.legs.steps.navigationInstruction',
                ]),
            ])->post('https://routes.googleapis.com/directions/v2:computeRoutes', [
                'origin' => ['location' => ['latLng' => $origin]],
                'destination' => ['location' => ['latLng' => $destination]],
                'travelMode' => $mode,
                'polylineQuality' => 'HIGH_QUALITY',
                'polylineEncoding' => 'GEO_JSON_LINESTRING',
                'languageCode' => 'en-US',
                'units' => 'METRIC',
            ]);
        } catch (ConnectionException) {
            throw new RoutingUnavailableException('Directions timed out. Check your connection and try again.', 504);
        }
        if (! $response->successful()) {
            // No API keys, coordinates, or raw upstream responses in logs.
            Log::warning('Google Routes request failed', [
                'http_status' => $response->status(),
                'google_status' => $response->json('error.status'),
                'reason' => $response->json('error.details.0.reason'),
                'travel_mode' => $mode,
            ]);
            throw new RoutingUnavailableException('Google directions are temporarily unavailable. Please try again later.', 503);
        }
        $routes = $response->json('routes', []);
        if (! is_array($routes) || count($routes) === 0) {
            throw new RoutingUnavailableException('No route was found for this travel mode. Try another mode or destination.', 422);
        }
        if (count(data_get($routes, '0.polyline.geoJsonLinestring.coordinates', [])) < 2) {
            throw new RoutingUnavailableException('Google returned an incomplete route. Please try again.', 502);
        }

        return ['provider' => 'google', 'travel_mode' => $mode, 'routes' => $routes];
    }
}
