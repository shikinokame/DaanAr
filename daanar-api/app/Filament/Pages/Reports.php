<?php

namespace App\Filament\Pages;

use App\Models\Landmark;
use App\Models\LandmarkVisit;
use App\Models\Municipality;
use App\Services\LandmarkReportExport;
use Carbon\Carbon;
use Filament\Facades\Filament;
use Filament\Pages\Page;
use Filament\Tables;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
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
            'today' => [now()->startOfDay(), now()->endOfDay(), 'Today ('.now()->format('M d, Y').')'],
            'week' => [now()->startOfWeek(), now()->endOfWeek(), 'This Week ('.now()->startOfWeek()->format('M d').' – '.now()->endOfWeek()->format('M d, Y').')'],
            'month' => [now()->startOfMonth(), now()->endOfMonth(), 'This Month ('.now()->format('F Y').')'],
            'custom' => [
                $this->startDate ? Carbon::parse($this->startDate)->startOfDay() : null,
                $this->endDate ? Carbon::parse($this->endDate)->endOfDay() : null,
                'Custom ('.($this->startDate ?: 'Start').' to '.($this->endDate ?: 'Now').')',
            ],
            default => [null, null, 'All Time'],
        };
    }

    protected function buildAnalyticsQuery(): Builder
    {
        [$start, $end] = $this->getResolvedDateRange();

        $visitsByLandmark = LandmarkVisit::query()
            ->select('landmark_id')
            ->selectRaw("COUNT(CASE WHEN action_type = 'PHYSICAL_VISIT' THEN 1 END) as total_physical_visits")
            ->selectRaw("COUNT(DISTINCT CASE WHEN action_type = 'PHYSICAL_VISIT' THEN COALESCE(CAST(user_id AS CHAR), device_id) END) as unique_visitors")
            ->selectRaw("COUNT(CASE WHEN action_type = 'AR_VIEW' THEN 1 END) as viewed_in_ar")
            ->selectRaw("COUNT(DISTINCT CASE WHEN action_type = 'AR_VIEW' THEN COALESCE(CAST(user_id AS CHAR), device_id) END) as unique_ar_viewers")
            ->selectRaw("COUNT(CASE WHEN action_type = 'MAP_NAV' THEN 1 END) as map_navigations")
            ->selectRaw('MAX(COALESCE(visited_at, created_at)) as last_visited_at')
            ->when($start, fn ($query) => $query->where('created_at', '>=', $start))
            ->when($end, fn ($query) => $query->where('created_at', '<=', $end))
            ->groupBy('landmark_id');

        return Landmark::query()
            ->select([
                'landmarks.*',
                DB::raw('COALESCE(visit_totals.total_physical_visits, 0) as total_physical_visits'),
                DB::raw('COALESCE(visit_totals.unique_visitors, 0) as unique_visitors'),
                DB::raw('COALESCE(visit_totals.viewed_in_ar, 0) as viewed_in_ar'),
                DB::raw('COALESCE(visit_totals.unique_ar_viewers, 0) as unique_ar_viewers'),
                DB::raw('COALESCE(visit_totals.map_navigations, 0) as map_navigations'),
                'visit_totals.last_visited_at',
            ])
            ->leftJoinSub($visitsByLandmark, 'visit_totals', 'visit_totals.landmark_id', '=', 'landmarks.id')
            ->with('municipality');
    }

    public function table(Table $table): Table
    {
        return $table
            ->query(fn (): Builder => $this->buildAnalyticsQuery())
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Landmark')
                    ->description(fn (Landmark $record): string => ($record->municipality?->name ?? 'Pangasinan').' • '.ucfirst((string) $record->category))
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
                        $state > 0 => 'info',
                        default => 'gray',
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
                        'church' => 'Church',
                        'park' => 'Park',
                        'historical' => 'Historical',
                        'natural' => 'Natural',
                        'cultural' => 'Cultural',
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

        $totals = LandmarkVisit::query()
            ->whereIn('action_type', [LandmarkVisit::ACTION_PHYSICAL_VISIT, LandmarkVisit::ACTION_AR_VIEW])
            ->when($start, fn ($query) => $query->where('created_at', '>=', $start))
            ->when($end, fn ($query) => $query->where('created_at', '<=', $end))
            ->selectRaw('action_type, COUNT(*) as total, COUNT(DISTINCT COALESCE(CAST(user_id AS CHAR), device_id)) as unique_people')
            ->groupBy('action_type')
            ->get()
            ->keyBy('action_type');
        $today = today();
        $todayCounts = LandmarkVisit::query()
            ->whereIn('action_type', [LandmarkVisit::ACTION_PHYSICAL_VISIT, LandmarkVisit::ACTION_AR_VIEW])
            ->where('created_at', '>=', $today)
            ->where('created_at', '<', $today->copy()->addDay())
            ->selectRaw('action_type, COUNT(*) as total')
            ->groupBy('action_type')
            ->pluck('total', 'action_type');
        $physical = $totals->get(LandmarkVisit::ACTION_PHYSICAL_VISIT);
        $ar = $totals->get(LandmarkVisit::ACTION_AR_VIEW);

        // Most Visited Site in selected period (by on-site physical visits first, then AR views)
        $topRow = $this->buildAnalyticsQuery()
            ->without('municipality')
            ->orderByDesc('total_physical_visits')
            ->orderByDesc('viewed_in_ar')
            ->first();

        $hasActivity = $topRow && (((int) $topRow->total_physical_visits) > 0 || ((int) $topRow->viewed_in_ar) > 0);

        return [
            'period_label' => $periodLabel,
            'total_physical_visits' => (int) ($physical?->total ?? 0),
            'today_physical_visits' => (int) ($todayCounts[LandmarkVisit::ACTION_PHYSICAL_VISIT] ?? 0),
            'unique_visitors' => (int) ($physical?->unique_people ?? 0),
            'unique_ar_viewers' => (int) ($ar?->unique_people ?? 0),
            'total_ar_views' => (int) ($ar?->total ?? 0),
            'today_ar_views' => (int) ($todayCounts[LandmarkVisit::ACTION_AR_VIEW] ?? 0),
            'most_visited_site' => $hasActivity ? $topRow->name : ' ',
            'most_visited_physical' => $hasActivity ? (int) $topRow->total_physical_visits : 0,
            'most_visited_ar' => $hasActivity ? (int) $topRow->viewed_in_ar : 0,
        ];
    }

    /**
     * Export the currently filtered Landmark Visit Analytics table as CSV.
     */
    public function exportCsv(): StreamedResponse
    {
        $report = $this->getExportReport();
        $filename = 'daanar-landmark-analytics-'.now()->format('Y-m-d_His').'.csv';

        return response()->streamDownload(function () use ($report) {
            $out = fopen('php://output', 'w');
            try {
                app(LandmarkReportExport::class)->writeCsv($out, $report);
            } finally {
                fclose($out);
            }
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Cache-Control' => 'private, no-store',
        ]);
    }

    public function exportExcel(): BinaryFileResponse
    {
        $report = $this->getExportReport();
        $path = tempnam(sys_get_temp_dir(), 'daanar-report-');
        if ($path === false) {
            throw new \RuntimeException('Could not prepare the Excel report.');
        }
        try {
            app(LandmarkReportExport::class)->writeExcel($path, $report);

            return response()->download($path, 'daanar-landmark-analytics-'.now()->format('Y-m-d_His').'.xlsx', [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'Cache-Control' => 'private, no-store',
            ])->deleteFileAfterSend(true);
        } catch (\Throwable $error) {
            @unlink($path);
            throw $error;
        }
    }

    public function printReport(): string
    {
        return view('filament.reports.landmark-print', ['report' => $this->getExportReport()])->render();
    }

    protected function getExportReport(): array
    {
        abort_unless(auth()->user()?->canAccessPanel(Filament::getCurrentPanel()), 403);
        [, , $period] = $this->getResolvedDateRange();
        $municipality = $this->tableFilters['municipality_id']['value'] ?? null;
        $category = $this->tableFilters['category']['value'] ?? null;
        $filters = [
            'Municipality: '.($municipality
                ? (Municipality::find($municipality)?->name ?? 'Unknown') : 'All'),
            'Category: '.($category ? ucfirst($category) : 'All'),
        ];
        if (filled($this->tableSearch)) {
            $filters[] = 'Search: '.$this->tableSearch;
        }

        // Same filtered and sorted query as the table, without pagination.
        return app(LandmarkReportExport::class)->data(
            $this->getFilteredSortedTableQuery()->get(), $period, implode(' | ', $filters),
        );
    }
}
