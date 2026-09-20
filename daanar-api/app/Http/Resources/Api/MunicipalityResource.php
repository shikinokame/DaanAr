<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MunicipalityResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'          => $this->id,
            'name'        => $this->name,
            'province'    => $this->province,
            'location'    => [
                'lat' => (float) $this->lat,
                'lng' => (float) $this->lng,
            ],
            'description'     => $this->description,
            'landmarks_count' => $this->whenCounted('landmarks'),
            'updated_at'  => $this->updated_at?->toIso8601String(),
        ];
    }
}
