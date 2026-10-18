<?php

namespace App\Filament\Pages;

use App\Models\Landmark;
use App\Models\LandmarkVisit;
use Carbon\Carbon;
use Filament\Pages\Page;
use Filament\Tables;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class Reports extends Page implements HasTable
{
    use InteractsWithTable;

    protected static ?string $navigationIcon = 'heroicon-o-chart-bar';

    protected static ?string $navigationLabel = 'Reports';

    protected static ?string $navigationGroup = 'Analytics';

    protected static ?int $navigationSort = 5;

    protected static string $view = 'filament.pages.reports';

    protected static ?string $title = 'Landmark Visit Reports';

    /** Date period filter: 'all', 'today', 'week', 'month', 'custom' */
    public string $datePeriod = 'all';

    public ?string $startDate = null;

    public ?string $endDate = null;

    public function updatedDatePeriod(): void
    {
        if ($this->datePeriod !== 'custom') {
            $this->startDate = null;
            $this->endDate = null;
        } else {
            $this->startDate ??= now()->subDays(30)->toDateString();
            $this->endDate ??= now()->toDateString();
        }

        $this->resetTable();
    }

    public function updatedStartDate(): void
    {
        $this->resetTable();
    }

    public function updatedEndDate(): void
    {
        $this->resetTable();
    }

    /**
     * Resolve active [Carbon $start, Carbon $end] range from the selected filter.
     *
     * @return array{0: ?Carbon, 1: ?Carbon, 2: string}
     */
    public function getResolvedDateRange(): array
    {
        return match ($this->datePeriod) {
            'today' => [now()->startOfDay(), now()->endOfDay(), 'Today (' . now()->format('M d, Y') . ')'],
            'week'  => [now()->startOfWeek(), now()->endOfWeek(), 'This Week (' . now()->startOfWeek()->format('M d') . ' – ' . now()->endOfWeek()->format('M d, Y') . ')'],
            'month' => [now()->startOfMonth(), now()->endOfMonth(), 'This Month (' . now()->format('F Y') . ')'],
            'custom' => [
                $this->startDate ? Carbon::parse($this->startDate)->startOfDay() : null,
                $this->endDate ? Carbon::parse($this->endDate)->endOfDay() : null,
                'Custom (' . ($this->startDate ?: 'Start') . ' to ' . ($this->endDate ?: 'Now') . ')',
            ],
            default => [null, null, 'All Time'],
        };
    }

    protected function buildAnalyticsQuery(): Builder
    {
        [$start, $end] = $this->getResolvedDateRange();

        return Landmark::query()
            ->select([
                'landmarks.*',
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'PHYSICAL_VISIT' THEN 1 END) as total_physical_visits"),
                DB::raw("COUNT(DISTINCT CASE WHEN landmark_visits.action_type = 'PHYSICAL_VISIT' THEN COALESCE(CAST(landmark_visits.user_id AS CHAR), landmark_visits.device_id) END) as unique_visitors"),
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'AR_VIEW' THEN 1 END) as viewed_in_ar"),
                DB::raw("COUNT(DISTINCT CASE WHEN landmark_visits.action_type = 'AR_VIEW' THEN COALESCE(CAST(landmark_visits.user_id AS CHAR), landmark_visits.device_id) END) as unique_ar_viewers"),
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'MAP_NAV' THEN 1 END) as map_navigations"),
                DB::raw('MAX(COALESCE(landmark_visits.visited_at, landmark_visits.created_at)) as last_visited_at'),
            ])
            ->leftJoin('landmark_visits', function ($join) use ($start, $end) {
                $join->on('landmarks.id', '=', 'landmark_visits.landmark_id');
                if ($start) {
                    $join->where('landmark_visits.created_at', '>=', $start);
                }
                if ($end) {
                    $join->where('landmark_visits.created_at', '<=', $end);
                }
            })
            ->groupBy('landmarks.id')
            ->with('municipality');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(fn (): Builder => $this->buildAnalyticsQuery())
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Landmark')
                    ->description(fn (Landmark $record): string => ($record->municipality?->name ?? 'Pangasinan') . ' • ' . ucfirst((string) $record->category))
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('total_physical_visits')
                    ->label('Total Visits (On-Site)')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => match (true) {
                        $state >= 50 => 'success',
                        $state >= 10 => 'warning',
                        $state > 0   => 'info',
                        default      => 'gray',
                    })
                    ->icon('heroicon-m-map-pin')
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('unique_visitors')
                    ->label('Unique Visitors')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'success' : 'gray')
                    ->icon('heroicon-m-users'),

                Tables\Columns\TextColumn::make('viewed_in_ar')
                    ->label('Viewed in AR')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'primary' : 'gray')
                    ->icon('heroicon-m-cube-transparent')
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('unique_ar_viewers')
                    ->label('Unique AR Viewers')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'info' : 'gray')
                    ->icon('heroicon-m-user-group'),

                Tables\Columns\TextColumn::make('map_navigations')
                    ->label('Map Navigations')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'warning' : 'gray')
                    ->icon('heroicon-m-arrow-trending-up'),

                Tables\Columns\TextColumn::make('last_visited_at')
                    ->label('Last Activity')
                    ->dateTime('M d, Y h:i A')
                    ->sortable()
                    ->placeholder('No activity yet')
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
            ->defaultSort('total_physical_visits', 'desc')
            ->paginated([10, 25, 50])
            ->heading('Landmark Visit Analytics')
            ->description('Separate on-site physical foot traffic (GPS geofence / QR) from virtual 3D AR views and route navigations.')
            ->emptyStateHeading('No visit data yet')
            ->emptyStateDescription('Analytics will appear here once registered users explore landmarks in the DaanAR app.')
            ->emptyStateIcon('heroicon-o-chart-bar');
    }

    public function getStatsData(): array
    {
        [$start, $end, $periodLabel] = $this->getResolvedDateRange();

        $applyDate = function ($q) use ($start, $end) {
            if ($start) {
                $q->where('created_at', '>=', $start);
            }
            if ($end) {
                $q->where('created_at', '<=', $end);
            }
        };

        $physicalQuery = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT);
        $applyDate($physicalQuery);
        $totalPhysicalVisits = (clone $physicalQuery)->count();

        $todayPhysicalVisits = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT)
            ->whereDate('created_at', today())
            ->count();

        // Unique Visitors: COUNT(DISTINCT user_id) across visits in the active period
        // Falls back to distinct COALESCE(user_id, device_id) so legacy logs also count accurately
        $uniquePhysicalVisitorsQuery = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT);
        $applyDate($uniquePhysicalVisitorsQuery);
        $uniquePhysicalVisitors = (int) (clone $uniquePhysicalVisitorsQuery)
            ->selectRaw('COUNT(DISTINCT COALESCE(CAST(user_id AS CHAR), device_id)) as aggregate')
            ->value('aggregate');

        $uniqueAllActiveQuery = LandmarkVisit::query();
        $applyDate($uniqueAllActiveQuery);
        $uniqueAllActive = (int) (clone $uniqueAllActiveQuery)
            ->selectRaw('COUNT(DISTINCT COALESCE(CAST(user_id AS CHAR), device_id)) as aggregate')
            ->value('aggregate');

        $uniqueVisitors = $uniquePhysicalVisitors > 0 ? $uniquePhysicalVisitors : $uniqueAllActive;

        $arQuery = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_AR_VIEW);
        $applyDate($arQuery);
        $totalArViews = (clone $arQuery)->count();

        $todayArViews = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_AR_VIEW)
            ->whereDate('created_at', today())
            ->count();

        // Most Visited Site in selected period (by on-site physical visits first, then AR views)
        $topRow = $this->buildAnalyticsQuery()
            ->orderByDesc('total_physical_visits')
            ->orderByDesc('viewed_in_ar')
            ->first();

        $hasActivity = $topRow && (((int) $topRow->total_physical_visits) > 0 || ((int) $topRow->viewed_in_ar) > 0);

        return [
            'period_label'          => $periodLabel,
            'total_physical_visits' => $totalPhysicalVisits,
            'today_physical_visits' => $todayPhysicalVisits,
            'unique_visitors'       => $uniqueVisitors,
            'unique_physical_only'  => $uniquePhysicalVisitors,
            'total_ar_views'        => $totalArViews,
            'today_ar_views'        => $todayArViews,
            'most_visited_site'     => $hasActivity ? $topRow->name : '—',
            'most_visited_physical' => $hasActivity ? (int) $topRow->total_physical_visits : 0,
            'most_visited_ar'       => $hasActivity ? (int) $topRow->viewed_in_ar : 0,
        ];
    }

    /**
     * Export the currently filtered Landmark Visit Analytics table as CSV.
     */
    public function exportCsv(): StreamedResponse
    {
        [, , $periodLabel] = $this->getResolvedDateRange();
        $rows = $this->getFilteredSortedTableQuery()->get();
        $filename = 'daanar-landmark-analytics-' . now()->format('Y-m-d_His') . '.csv';

        return response()->streamDownload(function () use ($rows, $periodLabel) {
            $out = fopen('php://output', 'w');
            // UTF-8 BOM for Excel compatibility
            fwrite($out, "\xEF\xBB\xBF");

            fputcsv($out, ['DaanAR Landmark Visit Analytics Report']);
            fputcsv($out, ['Date Period', $periodLabel, 'Generated At', now()->format('Y-m-d H:i:s')]);
            fputcsv($out, []);
            fputcsv($out, [
                'Landmark',
                'Municipality',
                'Category',
                'Total Visits (On-Site)',
                'Unique Visitors',
                'Viewed in AR',
                'Unique AR Viewers',
                'Map Navigations',
                'Last Activity',
            ]);

            foreach ($rows as $row) {
                fputcsv($out, [
                    $row->name,
                    $row->municipality?->name ?? 'Pangasinan',
                    ucfirst((string) $row->category),
                    (int) $row->total_physical_visits,
                    (int) $row->unique_visitors,
                    (int) $row->viewed_in_ar,
                    (int) $row->unique_ar_viewers,
                    (int) $row->map_navigations,
                    $row->last_visited_at
                        ? Carbon::parse($row->last_visited_at)->format('Y-m-d H:i:s')
                        : 'No activity yet',
                ]);
            }

            fclose($out);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }
}
