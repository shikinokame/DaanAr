<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LandmarkResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                => $this->id,
            'name'              => $this->name,
            'short_description' => $this->short_description,
            'description'       => $this->description,
            'category'          => $this->category,
            'era'               => $this->era,
            'address'           => $this->address,
            'location'          => [
                'lat' => (float) $this->lat,
                'lng' => (float) $this->lng,
            ],
            'municipality'      => new MunicipalityResource($this->whenLoaded('municipality')),
            'media'             => [
                'hero_image'      => $this->hero_image
                    ? asset('storage/' . $this->hero_image)
                    : null,
                'ar_marker_image' => $this->ar_marker_image
                    ? asset('storage/' . $this->ar_marker_image)
                    : null,
                'ar_model_url'    => $this->ar_model_url
                    ? asset('storage/' . $this->ar_model_url)
                    : null,
                'ar_html_path'    => $this->ar_html_path
                    ? url($this->ar_html_path)
                    : null,
            ],
            'is_featured'  => $this->is_featured,
            'created_at'   => $this->created_at?->toIso8601String(),
            'updated_at'   => $this->updated_at?->toIso8601String(),
        ];
    }
}
