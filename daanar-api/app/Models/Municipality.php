<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Municipality extends Model
{
    protected $fillable = [
        'name',
        'province',
        'lat',
        'lng',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'decimal:8',
            'lng' => 'decimal:8',
        ];
    }

    public function landmarks(): HasMany
    {
        return $this->hasMany(Landmark::class);
    }

    public function trails(): HasMany
    {
        return $this->hasMany(Trail::class);
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }
}
