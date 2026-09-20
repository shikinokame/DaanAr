<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Landmark extends Model
{
    protected $fillable = [
        'municipality_id',
        'name',
        'description',
        'short_description',
        'category',
        'era',
        'address',
        'lat',
        'lng',
        'hero_image',
        'ar_marker_image',
        'ar_model_url',
        'ar_html_path',
        'is_featured',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'decimal:8',
            'lng' => 'decimal:8',
            'is_featured' => 'boolean',
        ];
    }

    public function municipality(): BelongsTo
    {
        return $this->belongsTo(Municipality::class);
    }

    public function trails(): BelongsToMany
    {
        return $this->belongsToMany(Trail::class, 'trail_landmarks')
            ->withPivot('order')
            ->orderByPivot('order');
    }
}
