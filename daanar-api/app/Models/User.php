<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    use HasApiTokens, HasFactory, Notifiable;

    /** Single role for all mobile app visitors (replaces Tourist / Student / Educator). */
    public const ROLE_NORMAL_USER = 'Normal User';

    /** Legacy mobile roles merged into ROLE_NORMAL_USER. */
    public const LEGACY_MOBILE_ROLES = ['Tourist', 'Student', 'Educator'];

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'phone_number',
        'password',
        'role',
        'user_role',
        'status',
        'municipality_id',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function municipality(): BelongsTo
    {
        return $this->belongsTo(Municipality::class);
    }

    public function visits(): HasMany
    {
        return $this->hasMany(LandmarkVisit::class);
    }

    public function canAccessPanel(Panel $panel): bool
    {
        if (strtolower((string) $this->status) === 'blocked') {
            return false;
        }

        return in_array($this->role, ['admin', 'officer', 'super_admin'], true);
    }

    public function isAdmin(): bool
    {
        return in_array($this->role, ['super_admin', 'admin', 'officer'], true);
    }

    public function isSuperAdmin(): bool
    {
        return in_array($this->role, ['super_admin', 'admin', 'officer'], true);
    }

    public function isOfficer(): bool
    {
        return false;
    }

    /** Alias kept for Filament resource/widget compatibility */
    public function isLguEditor(): bool
    {
        return false;
    }

    /**
     * Normalize a Philippine mobile number to E.164 (+639XXXXXXXXX).
     */
    public static function normalizePhoneNumber(string $raw): string
    {
        $digits = preg_replace('/\D+/', '', $raw) ?? '';
        if (str_starts_with($digits, '09') && strlen($digits) === 11) {
            return '+63' . substr($digits, 1);
        }
        if (str_starts_with($digits, '9') && strlen($digits) === 10) {
            return '+63' . $digits;
        }
        if (str_starts_with($digits, '639') && strlen($digits) === 12) {
            return '+' . $digits;
        }

        return '+' . ltrim($raw, '+');
    }

    /**
     * Mask a phone number for privacy compliance: `+63 917 *** 4521`.
     */
    public static function maskPhone(?string $phone): string
    {
        if (! $phone) {
            return '—';
        }

        $normalized = self::normalizePhoneNumber($phone);
        // Expected: +639XXXXXXXXX (13 chars)
        if (preg_match('/^\+63(\d{3})\d{3}(\d{4})$/', $normalized, $m)) {
            return "+63 {$m[1]} *** {$m[2]}";
        }

        if (strlen($normalized) > 6) {
            return substr($normalized, 0, 4) . ' *** ' . substr($normalized, -4);
        }

        return $normalized;
    }
}
