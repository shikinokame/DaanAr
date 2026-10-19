<?php

namespace App\Filament\Widgets;

use App\Models\Landmark;
use App\Models\LandmarkVisit;
use App\Models\Municipality;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Facades\Auth;

class DaanArStatsWidget extends BaseWidget
{
    protected static ?int $sort = 1;

    protected function getColumns(): int
    {
        return 4;
    }

    protected function getStats(): array
    {
        $user = Auth::user();

        $landmarkQuery = Landmark::query();
        $visitQuery = LandmarkVisit::query();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $landmarkQuery->where('municipality_id', $user->municipality_id);
            $visitQuery->whereHas('landmark', function ($q) use ($user) {
                $q->where('municipality_id', $user->municipality_id);
            });
        }

        $landmarkCount = $landmarkQuery->count();
        $arReadyCount = (clone $landmarkQuery)
            ->where(function ($q) {
                $q->where('is_ar_ready', true)->orWhereNotNull('ar_model_url');
            })
            ->count();

        $municipalityCount = $user?->isLguEditor()
            ? 1
            : Municipality::count();

        $physicalVisits = (clone $visitQuery)
            ->where(function ($q) {
                $q->where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT)
                  ->orWhereNull('action_type');
            })
            ->count();

        $arViews = (clone $visitQuery)
            ->where('action_type', LandmarkVisit::ACTION_AR_VIEW)
            ->count();

        return [
            Stat::make('Total Landmarks', number_format($landmarkCount))
                ->description("{$arReadyCount} with 3D / AR models ready")
                ->descriptionIcon('heroicon-m-building-library')
                ->color('primary'),

            Stat::make('Total Municipalities', number_format($municipalityCount))
                ->description('Heritage coverage areas')
                ->descriptionIcon('heroicon-m-map')
                ->color('success'),

            Stat::make('Verified On-Site Visits', number_format($physicalVisits))
                ->description('Physical foot traffic (GPS ≤ 100m)')
                ->descriptionIcon('heroicon-m-map-pin')
                ->color('warning'),

            Stat::make('Virtual AR Views', number_format($arViews))
                ->description('3D & AR camera inspections')
                ->descriptionIcon('heroicon-m-cube-transparent')
                ->color('info'),
        ];
    }
}
