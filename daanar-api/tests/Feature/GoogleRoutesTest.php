<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GoogleRoutesTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google_routes.key' => 'server-test-key']);
        Http::preventStrayRequests();
    }

    private function signIn(): void
    {
        Sanctum::actingAs((new User)->forceFill(['id' => 123, 'status' => 'Active']), ['*']);
    }

    private function payload(string $mode = 'WALK'): array
    {
        return [
            'origin' => ['latitude' => 16.0813, 'longitude' => 120.3427],
            'destination' => ['latitude' => 16.08177992, 'longitude' => 120.34313365],
            'travel_mode' => $mode,
        ];
    }

    private function route(): array
    {
        return ['routes' => [[
            'distanceMeters' => 80, 'duration' => '60s',
            'polyline' => ['geoJsonLinestring' => ['type' => 'LineString', 'coordinates' => [[120.3427, 16.0813], [120.34313365, 16.08177992]]]],
            'warnings' => ['Use the pedestrian entrance.'],
        ]]];
    }

    public function test_anonymous_requests_never_call_google(): void
    {
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertUnauthorized();
        Http::assertNothingSent();
    }

    public function test_coordinates_and_mode_are_validated_before_billing(): void
    {
        $this->signIn();
        $payload = $this->payload('FOOT');
        $payload['origin']['latitude'] = 200;
        $this->postJson('/api/v1/routes/compute', $payload)->assertUnprocessable()
            ->assertJsonValidationErrors(['origin.latitude', 'travel_mode']);
        Http::assertNothingSent();
    }

    public function test_walking_request_preserves_geometry_warnings_and_server_key(): void
    {
        $this->signIn();
        Http::fake(['routes.googleapis.com/*' => Http::response($this->route())]);
        $response = $this->postJson('/api/v1/routes/compute', $this->payload())->assertOk()
            ->assertJsonPath('provider', 'google')->assertJsonPath('travel_mode', 'WALK')
            ->assertJsonPath('routes.0.distanceMeters', 80)
            ->assertJsonPath('routes.0.warnings.0', 'Use the pedestrian entrance.');
        $this->assertStringContainsString('no-store', $response->headers->get('Cache-Control'));
        $response->assertDontSee('server-test-key');
        Http::assertSent(fn ($r) => $r->hasHeader('X-Goog-Api-Key', 'server-test-key')
            && $r['travelMode'] === 'WALK' && $r['origin']['location']['latLng']['latitude'] === 16.0813
            && $r['polylineQuality'] === 'HIGH_QUALITY' && $r['polylineEncoding'] === 'GEO_JSON_LINESTRING');
        Http::assertSentCount(1);
    }

    public function test_driving_and_bicycle_modes_are_not_silently_changed(): void
    {
        $this->signIn();
        Http::fake(['routes.googleapis.com/*' => Http::response($this->route())]);
        foreach (['DRIVE', 'BICYCLE'] as $mode) {
            $this->postJson('/api/v1/routes/compute', $this->payload($mode))->assertOk()->assertJsonPath('travel_mode', $mode);
            Http::assertSent(fn ($r) => $r['travelMode'] === $mode);
        }
    }

    public function test_missing_configuration_does_not_call_an_old_provider(): void
    {
        $this->signIn();
        config(['services.google_routes.key' => null]);
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertStatus(503);
        Http::assertNothingSent();
    }

    public function test_google_permission_errors_are_not_returned_as_user_blocks(): void
    {
        $this->signIn();
        Http::fake(['routes.googleapis.com/*' => Http::response(['error' => ['status' => 'PERMISSION_DENIED', 'message' => 'Private upstream detail']], 403)]);
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertStatus(503)->assertDontSee('Private upstream detail');
        Http::assertSentCount(1);
    }

    public function test_google_diagnostics_redact_secrets_and_locations_and_find_error_info(): void
    {
        $this->signIn();
        Log::spy();
        Http::fake(['routes.googleapis.com/*' => Http::response(['error' => [
            'status' => 'PERMISSION_DENIED',
            'message' => 'Access denied for server-test-key at 16.0813,120.3427; https://example.test/?key=secret',
            'details' => [
                ['@type' => 'type.googleapis.com/google.rpc.LocalizedMessage'],
                ['@type' => 'type.googleapis.com/google.rpc.ErrorInfo', 'reason' => 'ACCESS_DENIED',
                    'metadata' => ['service' => 'routes.googleapis.com', 'apiName' => 'routes', 'private' => 'do-not-log']],
            ],
        ]], 403)]);
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertStatus(503)->assertDontSee('Access denied');
        Log::shouldHaveReceived('warning')->once()->with('Google Routes request failed', \Mockery::on(function ($context) {
            $logged = json_encode($context);

            return $context['reason'] === 'ACCESS_DENIED'
                && $context['service'] === 'routes.googleapis.com'
                && str_contains($context['google_message'], 'Access denied')
                && ! str_contains($logged, 'server-test-key')
                && ! str_contains($logged, '16.0813')
                && ! str_contains($logged, '120.3427')
                && ! str_contains($logged, 'example.test')
                && ! str_contains($logged, 'do-not-log');
        }));
    }

    public function test_no_route_does_not_create_a_straight_line_fallback(): void
    {
        $this->signIn();
        Http::fake(['routes.googleapis.com/*' => Http::response(['routes' => []])]);
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertUnprocessable()->assertJsonMissingPath('routes');
    }

    public function test_timeout_is_visible_without_retrying_billable_requests(): void
    {
        $this->signIn();
        Http::fake(fn () => throw new ConnectionException('Timed out'));
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertStatus(504);
    }

    public function test_request_rate_is_limited_before_calling_google(): void
    {
        $this->signIn();
        Http::fake(['routes.googleapis.com/*' => Http::response($this->route())]);
        for ($i = 0; $i < 12; $i++) {
            $this->postJson('/api/v1/routes/compute', $this->payload())->assertOk();
        }
        $this->postJson('/api/v1/routes/compute', $this->payload())->assertStatus(429);
        Http::assertSentCount(12);
    }
}
