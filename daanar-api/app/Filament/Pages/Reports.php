<?php

namespace App\Filament\Pages;

use App\Models\Landmark;
use App\Models\LandmarkVisit;
use App\Models\Municipality;
use Filament\Pages\Page;
use Filament\Tables;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class Reports extends Page implements HasTable
{
    use InteractsWithTable;

    protected static ?string $navigationIcon = 'heroicon-o-chart-bar';

    protected static ?string $navigationLabel = 'Reports';

    protected static ?string $navigationGroup = 'Analytics';

    protected static ?int $navigationSort = 5;

    protected static string $view = 'filament.pages.reports';

    protected static ?string $title = 'Landmark Visit Reports';

    public function table(Table $table): Table
    {
        return $table
            ->query(
                Landmark::query()
                    ->select([
                        'landmarks.*',
                        DB::raw('COUNT(landmark_visits.id) as visits_count'),
                        DB::raw('COUNT(DISTINCT landmark_visits.device_id) as unique_visitors'),
                        DB::raw('MAX(landmark_visits.visited_at) as last_visit_at'),
                    ])
                    ->leftJoin('landmark_visits', 'landmarks.id', '=', 'landmark_visits.landmark_id')
                    ->groupBy('landmarks.id')
                    ->with('municipality')
            )
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Landmark')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('municipality.name')
                    ->label('Municipality')
                    ->sortable()
                    ->badge()
                    ->color('gray'),

                Tables\Columns\TextColumn::make('category')
                    ->label('Category')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state))
                    ->color(fn (string $state): string => match ($state) {
                        'church'     => 'warning',
                        'park'       => 'success',
                        'historical' => 'info',
                        'natural'    => 'success',
                        'cultural'   => 'primary',
                        default      => 'gray',
                    }),

                Tables\Columns\TextColumn::make('visits_count')
                    ->label('Total Visits')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => match (true) {
                        $state >= 50 => 'success',
                        $state >= 10 => 'warning',
                        $state > 0   => 'info',
                        default      => 'gray',
                    })
                    ->icon('heroicon-m-eye')
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('unique_visitors')
                    ->label('Unique Visitors')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->icon('heroicon-m-users'),

                Tables\Columns\TextColumn::make('last_visit_at')
                    ->label('Last Visit')
                    ->dateTime('M d, Y h:i A')
                    ->sortable()
                    ->placeholder('No visits yet')
                    ->since(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('municipality_id')
                    ->label('Municipality')
                    ->relationship('municipality', 'name'),

                Tables\Filters\SelectFilter::make('category')
                    ->options([
                        'church'     => 'Church',
                        'park'       => 'Park',
                        'historical' => 'Historical',
                        'natural'    => 'Natural',
                        'cultural'   => 'Cultural',
                    ]),
            ])
            ->defaultSort('visits_count', 'desc')
            ->paginated([10, 25, 50])
            ->heading('Landmark Visit Analytics')
            ->description('Track how many users are visiting each landmark in the DaanAR app.')
            ->emptyStateHeading('No visit data yet')
            ->emptyStateDescription('Visit counts will appear here once users start exploring landmarks in the app.')
            ->emptyStateIcon('heroicon-o-chart-bar');
    }

    public function getStatsData(): array
    {
        $totalVisits   = LandmarkVisit::count();
        $uniqueDevices = LandmarkVisit::whereNotNull('device_id')
                                       ->distinct('device_id')
                                       ->count('device_id');
        $todayVisits   = LandmarkVisit::whereDate('visited_at', today())->count();
        $topLandmark   = Landmark::withCount('visits')
                                  ->orderByDesc('visits_count')
                                  ->first();

        return [
            'total_visits'    => $totalVisits,
            'unique_devices'  => $uniqueDevices,
            'today_visits'    => $todayVisits,
            'top_landmark'    => $topLandmark?->name ?? '—',
            'top_landmark_ct' => $topLandmark?->visits_count ?? 0,
        ];
    }
}
