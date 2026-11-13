<?php

namespace Tests\Feature;

use App\Models\Landmark;
use Tests\TestCase;

/** Read-only smoke coverage against the configured local test database. */
class PublicReadEndpointsTest extends TestCase
{
    public function test_cms_requires_login(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');
    }

    public function test_landmark_browsing_returns_paginated_records(): void
    {
        $this->getJson('/api/v1/landmarks?page=1')
            ->assertOk()
            ->assertJsonStructure(['data', 'meta']);
    }

    public function test_municipalities_and_trails_are_available(): void
    {
        $this->getJson('/api/v1/municipalities')->assertOk()->assertJsonStructure(['data']);
        $this->getJson('/api/v1/trails')->assertOk()->assertJsonStructure(['data']);
    }

    public function test_landmark_details_and_ar_page_render_for_an_existing_record(): void
    {
        $landmark = Landmark::query()->first();
        if (! $landmark) {
            $this->markTestSkipped('No landmark is available in the local test database.');
        }

        $this->getJson('/api/v1/landmarks/'.$landmark->id)->assertOk()->assertJsonStructure(['data']);
        $this->get('/ar/landmark/'.$landmark->id)->assertOk()->assertSee('model-viewer', false);
    }

    public function test_nonexistent_ar_model_returns_not_found(): void
    {
        $this->get('/storage/ar-models/test/does-not-exist.glb')->assertNotFound();
    }
}
