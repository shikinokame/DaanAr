<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class LocationHelperController extends Controller
{
    private const ALLOWED_MAP_HOSTS = [
        'maps.app.goo.gl',
        'goo.gl',
        'www.google.com',
        'google.com',
        'maps.google.com',
        'www.google.com.ph',
        'maps.google.com.ph',
    ];

    public function search(Request $request): JsonResponse
    {
        abort_unless(auth()->check(), 403);

        $query = trim((string) $request->query('q', ''));
        if (mb_strlen($query) < 2) {
            return response()->json(['results' => []]);
        }

        try {
            $response = Http::timeout(8)
                ->withHeaders([
                    'User-Agent' => 'DaanAR-Heritage-CMS/1.0 (Pangasinan Heritage Navigation)',
                    'Accept-Language' => 'en',
                ])
                ->get('https://nominatim.openstreetmap.org/search', [
                    'q' => $query,
                    'format' => 'jsonv2',
                    'addressdetails' => 1,
                    'limit' => 6,
                    'countrycodes' => 'ph',
                    // Bias results toward Pangasinan without blocking outside matches
                    'viewbox' => '119.70,16.45,120.90,15.65',
                    'bounded' => 0,
                ]);

            if (! $response->successful()) {
                return response()->json(['results' => []]);
            }

            $items = collect($response->json() ?: [])->map(function (array $item): array {
                return [
                    'display_name' => $item['display_name'] ?? '',
                    'name' => $item['name'] ?? '',
                    'lat' => isset($item['lat']) ? round((float) $item['lat'], 8) : null,
                    'lng' => isset($item['lon']) ? round((float) $item['lon'], 8) : null,
                ];
            })->filter(fn (array $r) => $r['lat'] !== null && $r['lng'] !== null)->values();

            return response()->json(['results' => $items]);
        } catch (\Throwable) {
            return response()->json(['results' => []]);
        }
    }

    public function reverse(Request $request): JsonResponse
    {
        abort_unless(auth()->check(), 403);

        $lat = filter_var($request->query('lat'), FILTER_VALIDATE_FLOAT);
        $lng = filter_var($request->query('lng'), FILTER_VALIDATE_FLOAT);

        if ($lat === false || $lng === false || $lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            return response()->json(['error' => 'Invalid coordinates.'], 422);
        }

        try {
            $response = Http::timeout(8)
                ->withHeaders([
                    'User-Agent' => 'DaanAR-Heritage-CMS/1.0 (Pangasinan Heritage Navigation)',
                    'Accept-Language' => 'en',
                ])
                ->get('https://nominatim.openstreetmap.org/reverse', [
                    'lat' => $lat,
                    'lon' => $lng,
                    'format' => 'jsonv2',
                    'zoom' => 18,
                    'addressdetails' => 1,
                ]);

            if (! $response->successful()) {
                return response()->json(['address' => null]);
            }

            $data = $response->json();

            return response()->json([
                'address' => $data['display_name'] ?? null,
            ]);
        } catch (\Throwable) {
            return response()->json(['address' => null]);
        }
    }

    public function resolveUrl(Request $request): JsonResponse
    {
        abort_unless(auth()->check(), 403);

        $rawUrl = trim((string) $request->query('url', ''));
        if (! $this->isAllowedMapUrl($rawUrl)) {
            return response()->json([
                'error' => 'Only Google Maps links (maps.app.goo.gl or google.com/maps) are supported.',
            ], 422);
        }

        try {
            $currentUrl = $rawUrl;
            $visited = [$currentUrl];

            // Manually step through up to 5 redirects while verifying each target host
            for ($i = 0; $i < 5; $i++) {
                $response = Http::timeout(8)
                    ->withoutRedirecting()
                    ->withHeaders([
                        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        'Accept-Language' => 'en-US,en;q=0.9',
                    ])
                    ->get($currentUrl);

                $coords = $this->extractCoordinatesFromText($currentUrl);
                if ($coords !== null) {
                    return response()->json([
                        'expanded_url' => $currentUrl,
                        'lat' => $coords['lat'],
                        'lng' => $coords['lng'],
                    ]);
                }

                if ($response->status() >= 300 && $response->status() < 400) {
                    $location = $response->header('Location');
                    if (! $location) {
                        break;
                    }
                    if (str_starts_with($location, '/')) {
                        $parts = parse_url($currentUrl);
                        $location = ($parts['scheme'] ?? 'https') . '://' . ($parts['host'] ?? 'www.google.com') . $location;
                    }
                    if (! $this->isAllowedMapUrl($location)) {
                        break;
                    }
                    $currentUrl = $location;
                    $visited[] = $currentUrl;
                    continue;
                }

                $bodyCoords = $this->extractCoordinatesFromText(substr($response->body(), 0, 120000));
                if ($bodyCoords !== null) {
                    return response()->json([
                        'expanded_url' => $currentUrl,
                        'lat' => $bodyCoords['lat'],
                        'lng' => $bodyCoords['lng'],
                    ]);
                }

                break;
            }

            foreach (array_reverse($visited) as $candidate) {
                $coords = $this->extractCoordinatesFromText($candidate);
                if ($coords !== null) {
                    return response()->json([
                        'expanded_url' => $candidate,
                        'lat' => $coords['lat'],
                        'lng' => $coords['lng'],
                    ]);
                }
            }

            return response()->json([
                'expanded_url' => $currentUrl,
                'lat' => null,
                'lng' => null,
                'error' => 'Could not extract coordinates from that short link. Try opening the link and copying the full URL or coordinates.',
            ], 422);
        } catch (\Throwable) {
            return response()->json([
                'error' => 'Unable to expand the short link right now.',
            ], 422);
        }
    }

    private function isAllowedMapUrl(string $url): bool
    {
        $parts = parse_url($url);
        if (! is_array($parts)) {
            return false;
        }

        $scheme = strtolower($parts['scheme'] ?? '');
        $host = strtolower($parts['host'] ?? '');

        if (! in_array($scheme, ['https', 'http'], true)) {
            return false;
        }

        return in_array($host, self::ALLOWED_MAP_HOSTS, true);
    }

    /**
     * @return array{lat: float, lng: float}|null
     */
    private function extractCoordinatesFromText(string $text): ?array
    {
        $decoded = rawurldecode($text);

        // 1. Exact Google Maps place pin (!3dLAT!4dLNG)
        if (preg_match_all('/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/', $decoded, $matches, PREG_SET_ORDER)) {
            $last = end($matches);
            $pair = $this->validPair((float) $last[1], (float) $last[2]);
            if ($pair !== null) {
                return $pair;
            }
        }

        // 2. Query / ll / center URL params
        if (preg_match('/[?&](?:q|ll|query|center|destination|daddr)=(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)/i', $decoded, $m)) {
            $pair = $this->validPair((float) $m[1], (float) $m[2]);
            if ($pair !== null) {
                return $pair;
            }
        }

        // 3. Google Maps @lat,lng viewport coordinates
        if (preg_match('/@(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)/', $decoded, $m)) {
            $pair = $this->validPair((float) $m[1], (float) $m[2]);
            if ($pair !== null) {
                return $pair;
            }
        }

        return null;
    }

    /**
     * @return array{lat: float, lng: float}|null
     */
    private function validPair(float $lat, float $lng): ?array
    {
        if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            return null;
        }

        return [
            'lat' => round($lat, 8),
            'lng' => round($lng, 8),
        ];
    }
}

