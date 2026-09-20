<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Trail extends Model
{
    protected $fillable = [
        'name',
        'description',
        'municipality_id',
        'difficulty',
        'estimated_time',
    ];

    protected function casts(): array
    {
        return [
            'estimated_time' => 'integer',
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
}
