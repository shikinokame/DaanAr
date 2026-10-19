<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Trail extends Model
{
    protected $fillable = [
        'name',
        'description',
        'municipality_id',
        'district',
        'difficulty',
        'estimated_time',
        'total_distance_metres',
    ];

    protected function casts(): array
    {
        return [
            'estimated_time'        => 'integer',
            'total_distance_metres' => 'integer',
        ];
    }

    public function municipality(): BelongsTo
    {
        return $this->belongsTo(Municipality::class);
    }

    public function landmarks(): BelongsToMany
    {
        return $this->belongsToMany(Landmark::class, 'trail_landmarks')
            ->withPivot('order')
            ->orderByPivot('order');
    }

    public function segments(): HasMany
    {
        return $this->hasMany(TrailSegment::class)->orderBy('order');
    }
}
