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
            // Only log a bounded, redacted explanation and allowlisted metadata.
            $message = $response->json('error.message');
            $message = is_string($message) ? $message : '';
            $privateValues = array_merge([$key], array_map('strval', array_values($origin)), array_map('strval', array_values($destination)));
            $message = str_replace($privateValues, '[redacted]', $message);
            $message = preg_replace('/AIza[\w-]+|https?:\/\/\S+/', '[redacted]', $message);
            $message = substr(str_replace(["\r", "\n"], ' ', $message), 0, 1000);
            $details = $response->json('error.details', []);
            $errorInfo = collect(is_array($details) ? $details : [])->first(
                fn ($detail) => is_array($detail) && ($detail['@type'] ?? '') === 'type.googleapis.com/google.rpc.ErrorInfo',
                []
            );
            Log::warning('Google Routes request failed', [
                'http_status' => $response->status(),
                'google_status' => $response->json('error.status'),
                'reason' => $errorInfo['reason'] ?? $response->json('error.details.0.reason'),
                'google_message' => $message,
                'service' => data_get($errorInfo, 'metadata.service'),
                'api_name' => data_get($errorInfo, 'metadata.apiName'),
                'method' => data_get($errorInfo, 'metadata.method'),
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
