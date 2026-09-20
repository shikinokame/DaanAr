<?php

namespace App\Filament\Widgets;

use App\Models\Landmark;
use App\Models\Municipality;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\Auth;

class DaanArStatsWidget extends BaseWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $user = Auth::user();

        $landmarkQuery = Landmark::query();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $landmarkQuery->where('municipality_id', $user->municipality_id);
        }

        $landmarkCount = $landmarkQuery->count();
        $municipalityCount = $user?->isLguEditor()
            ? 1
            : Municipality::count();

        return [
            Stat::make('Total Landmarks', $landmarkCount)
                ->description($user?->isLguEditor() ? 'In your municipality' : 'Across all municipalities')
                ->descriptionIcon('heroicon-m-building-library')
                ->color('primary'),
            Stat::make('Total Municipalities', $municipalityCount)
                ->description('Heritage coverage areas')
                ->descriptionIcon('heroicon-m-map-pin')
                ->color('success'),
        ];
    }
}
