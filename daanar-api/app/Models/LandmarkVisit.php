<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LandmarkVisit extends Model
{
    protected $fillable = [
        'landmark_id',
        'user_id',
        'device_id',
        'source',
        'visited_at',
    ];

    protected function casts(): array
    {
        return [
            'visited_at' => 'datetime',
        ];
    }

    public function landmark(): BelongsTo
    {
        return $this->belongsTo(Landmark::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
