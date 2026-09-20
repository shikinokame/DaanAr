<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'             => $this->id,
            'name'           => $this->name,
            'description'    => $this->description,
            'difficulty'     => $this->difficulty,
            'estimated_time' => $this->estimated_time, // in minutes
            'municipality'   => new MunicipalityResource($this->whenLoaded('municipality')),
            // Ordered landmarks are only included on the single-trail endpoint
            'landmarks'      => LandmarkResource::collection($this->whenLoaded('landmarks')),
            'landmarks_count'=> $this->whenCounted('landmarks'),
            'created_at'     => $this->created_at?->toIso8601String(),
            'updated_at'     => $this->updated_at?->toIso8601String(),
        ];
    }
}
