<?php

namespace App\Console\Commands;

use App\Models\Landmark;
use App\Models\Trail;
use App\Models\TrailSegment;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

class PrecomputeTrailRoutes extends Command
{
    protected $signature = 'trails:precompute-routes {--trail= : Optional Trail ID to precompute} {--force : Recompute even if segments already exist}';

    protected $description = 'Precompute ORS route polylines, distances, durations, and turn instructions for all trail segments';

    private const DEFAULT_ORS_KEY = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1YjMyNTA2MWI1NTRiMjE5MTAwZTU3ZDU4MmE4NDA1IiwiaCI6Im11cm11cjY0In0=';

    public function handle(): int
    {
        $query = Trail::with('landmarks');
        if ($this->option('trail')) {
            $query->whereKey($this->option('trail'));
        }

        $trails = $query->get();
        $orsKey = env('ORS_API_KEY', self::DEFAULT_ORS_KEY);

        foreach ($trails as $trail) {
            $stops = $trail->landmarks->values();
            if ($stops->count() < 2) {
                continue;
            }

            if (! $this->option('force') && $trail->segments()->count() === $stops->count() - 1) {
                $this->info("Skipping [{$trail->name}] (segments already precomputed).");
                continue;
            }

            $this->info("Precomputing segments for [{$trail->name}] ({$stops->count()} stops)...");

            $trail->segments()->delete();
            $totalDist = 0;
            $totalDur = 0;

            // Use foot-walking for single-town trails, driving-car for multi-town district trails
            $profile = $trail->municipality_id ? 'foot-walking' : 'driving-car';

            for ($i = 0; $i < $stops->count() - 1; $i++) {
                /** @var Landmark $from */
                $from = $stops[$i];
                /** @var Landmark $to */
                $to = $stops[$i + 1];

                $segmentData = $this->computeSegment($from, $to, $profile, $orsKey);

                TrailSegment::create([
                    'trail_id'         => $trail->id,
                    'order'            => $i + 1,
                    'from_landmark_id' => $from->id,
                    'to_landmark_id'   => $to->id,
                    'points_json'      => $segmentData['points'],
                    'encoded_polyline' => null,
                    'distance_m'       => $segmentData['distance_m'],
                    'duration_s'       => $segmentData['duration_s'],
                    'steps_json'       => $segmentData['steps'],
                ]);

                $totalDist += $segmentData['distance_m'];
                $totalDur += $segmentData['duration_s'];
            }

            $trail->total_distance_metres = $totalDist;
            if ($totalDur > 0) {
                $trail->estimated_time = max(5, (int) round($totalDur / 60));
            }
            $trail->save();
        }

        $this->info('Trail route precomputation complete.');

        return self::SUCCESS;
    }

    /**
     * Fetch route geometry & instructions from ORS, with deterministic Haversine fallback.
     */
    private function computeSegment(Landmark $from, Landmark $to, string $profile, string $orsKey): array
    {
        $fromLat = (float) $from->lat;
        $fromLng = (float) $from->lng;
        $toLat = (float) $to->lat;
        $toLng = (float) $to->lng;

        try {
            $resp = Http::timeout(6)
                ->withHeaders([
                    'Authorization' => $orsKey,
                    'Accept'        => 'application/json, application/geo+json',
                ])
                ->get("https://api.openrouteservice.org/v2/directions/{$profile}", [
                    'start' => "{$fromLng},{$fromLat}",
                    'end'   => "{$toLng},{$toLat}",
                ]);

            if ($resp->successful()) {
                $json = $resp->json();
                $feature = $json['features'][0] ?? null;
                if ($feature) {
                    $coords = $feature['geometry']['coordinates'] ?? [];
                    $points = array_map(
                        fn (array $c) => [(float) $c[1], (float) $c[0]],
                        $coords
                    );

                    $summary = $feature['properties']['summary'] ?? [];
                    $distanceM = (int) round((float) ($summary['distance'] ?? 0));
                    $durationS = (int) round((float) ($summary['duration'] ?? 0));

                    $rawSteps = $feature['properties']['segments'][0]['steps'] ?? [];
                    $steps = array_map(fn (array $st) => [
                        'instruction' => (string) ($st['instruction'] ?? 'Continue along route'),
                        'distance_m'  => (int) round((float) ($st['distance'] ?? 0)),
                        'duration_s'  => (int) round((float) ($st['duration'] ?? 0)),
                        'name'        => (string) ($st['name'] ?? ''),
                    ], $rawSteps);

                    if (! empty($points) && $distanceM > 0) {
                        return [
                            'points'     => $points,
                            'distance_m' => $distanceM,
                            'duration_s' => $durationS,
                            'steps'      => $steps,
                        ];
                    }
                }
            }
        } catch (\Throwable $e) {
            // Fall through to deterministic Haversine road approximation
        }

        $straightMetres = $this->haversineMetres($fromLat, $fromLng, $toLat, $toLng);
        $roadMetres = max(50, (int) round($straightMetres * 1.25));
        $speedMps = $profile === 'foot-walking' ? 1.35 : 8.5;
        $durationS = max(60, (int) round($roadMetres / $speedMps));
        $cardinal = $this->cardinalDirection($fromLat, $fromLng, $toLat, $toLng);

        $points = [
            [$fromLat, $fromLng],
            [round(($fromLat * 0.65) + ($toLat * 0.35), 6), round(($fromLng * 0.65) + ($toLng * 0.35), 6)],
            [round(($fromLat * 0.35) + ($toLat * 0.65), 6), round(($fromLng * 0.35) + ($toLng * 0.65), 6)],
            [$toLat, $toLng],
        ];

        $steps = [
            [
                'instruction' => "Head {$cardinal} from {$from->name}",
                'distance_m'  => (int) round($roadMetres * 0.7),
                'duration_s'  => (int) round($durationS * 0.7),
                'name'        => $to->address ?? '',
            ],
            [
                'instruction' => "Continue {$cardinal} toward {$to->name}",
                'distance_m'  => (int) round($roadMetres * 0.3),
                'duration_s'  => (int) round($durationS * 0.3),
                'name'        => $to->name,
            ],
            [
                'instruction' => "Arrive at {$to->name}",
                'distance_m'  => 0,
                'duration_s'  => 0,
                'name'        => $to->name,
            ],
        ];

        return [
            'points'     => $points,
            'distance_m' => $roadMetres,
            'duration_s' => $durationS,
            'steps'      => $steps,
        ];
    }

    private function haversineMetres(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371000.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return 2 * $earthRadius * asin(min(1.0, sqrt($a)));
    }

    private function cardinalDirection(float $lat1, float $lon1, float $lat2, float $lon2): string
    {
        $dLon = deg2rad($lon2 - $lon1);
        $y = sin($dLon) * cos(deg2rad($lat2));
        $x = cos(deg2rad($lat1)) * sin(deg2rad($lat2))
            - sin(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos($dLon);
        $brng = fmod((rad2deg(atan2($y, $x)) + 360.0), 360.0);

        $dirs = ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];

        return $dirs[(int) round($brng / 45) % 8];
    }
}

