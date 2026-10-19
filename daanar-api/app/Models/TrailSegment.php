<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrailSegment extends Model
{
    protected $fillable = [
        'trail_id',
        'order',
        'from_landmark_id',
        'to_landmark_id',
        'points_json',
        'encoded_polyline',
        'distance_m',
        'duration_s',
        'steps_json',
    ];

    protected function casts(): array
    {
        return [
            'order'       => 'integer',
            'distance_m'  => 'integer',
            'duration_s'  => 'integer',
            'points_json' => 'array',
            'steps_json'  => 'array',
        ];
    }

    public function trail(): BelongsTo
    {
        return $this->belongsTo(Trail::class);
    }

    public function fromLandmark(): BelongsTo
    {
        return $this->belongsTo(Landmark::class, 'from_landmark_id');
    }

    public function toLandmark(): BelongsTo
    {
        return $this->belongsTo(Landmark::class, 'to_landmark_id');
    }
}

