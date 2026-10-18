<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LandmarkVisit extends Model
{
    public const ACTION_PHYSICAL_VISIT = 'PHYSICAL_VISIT';
    public const ACTION_AR_VIEW        = 'AR_VIEW';
    public const ACTION_MAP_NAV        = 'MAP_NAV';
    public const ACTION_PAGE_VIEW      = 'PAGE_VIEW';

    public const ALLOWED_ACTIONS = [
        self::ACTION_PHYSICAL_VISIT,
        self::ACTION_AR_VIEW,
        self::ACTION_MAP_NAV,
        self::ACTION_PAGE_VIEW,
    ];

    protected $fillable = [
        'landmark_id',
        'user_id',
        'action_type',
        'verification_method',
        'user_lat',
        'user_lng',
        'device_id',
        'source',
        'visited_at',
    ];

    protected function casts(): array
    {
        return [
            'visited_at' => 'datetime',
            'user_lat'   => 'decimal:8',
            'user_lng'   => 'decimal:8',
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
