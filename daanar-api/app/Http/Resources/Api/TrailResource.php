<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TrailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                    => $this->id,
            'name'                  => $this->name,
            'description'           => $this->description,
            'district'              => $this->district,
            'difficulty'            => $this->difficulty,
            'estimated_time'        => $this->estimated_time, // in minutes
            'total_distance_metres' => $this->total_distance_metres,
            'municipality'          => new MunicipalityResource($this->whenLoaded('municipality')),
            'landmarks'             => LandmarkResource::collection($this->whenLoaded('landmarks')),
            'landmarks_count'       => $this->whenCounted('landmarks', $this->landmarks_count ?? ($this->relationLoaded('landmarks') ? $this->landmarks->count() : null)),
            'segments'              => $this->whenLoaded('segments', function () {
                return $this->segments->map(fn ($s) => [
                    'id'               => $s->id,
                    'order'            => $s->order,
                    'from_landmark_id' => $s->from_landmark_id,
                    'to_landmark_id'   => $s->to_landmark_id,
                    'points'           => $s->points_json ?? [],
                    'encoded_polyline' => $s->encoded_polyline,
                    'distance_m'       => $s->distance_m,
                    'duration_s'       => $s->duration_s,
                    'steps'            => $s->steps_json ?? [],
                ])->values();
            }),
            'created_at'            => $this->created_at?->toIso8601String(),
            'updated_at'            => $this->updated_at?->toIso8601String(),
        ];
    }
}
