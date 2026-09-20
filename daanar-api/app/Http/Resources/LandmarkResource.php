<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LandmarkResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'name'         => $this->name,
            'description'  => $this->description,
            'short_description' => $this->short_description,
            'category'     => $this->category,
            'era'          => $this->era,
            'address'      => $this->address,
            'municipality' => $this->whenLoaded('municipality', fn () => [
                'id'   => $this->municipality->id,
                'name' => $this->municipality->name,
            ]),
            'location' => [
                'latitude'  => (float) $this->lat,
                'longitude' => (float) $this->lng,
            ],
            'ar_marker' => [
                'image_url' => $this->ar_marker_image
                    ? asset('storage/' . $this->ar_marker_image)
                    : null,
            ],
            'models' => [
                'android_url' => $this->ar_model_url
                    ? asset('storage/' . $this->ar_model_url)
                    : null,
                'html_path'   => $this->ar_html_path
                    ? asset('storage/' . $this->ar_html_path)
                    : null,
            ],
            'hero_image_url' => $this->hero_image
                ? asset('storage/' . $this->hero_image)
                : null,
            'is_featured'  => $this->is_featured,
            'updated_at'   => $this->updated_at?->toIso8601String(),
        ];
    }
}
