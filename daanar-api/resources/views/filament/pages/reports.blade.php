<x-filament-panels::page>

    @php $stats = $this->getStatsData(); @endphp

    <style>
        @media print {
            .no-print,
            aside,
            header,
            nav,
            .fi-sidebar,
            .fi-topbar,
            .fi-ta-header-toolbar,
            .fi-pagination {
                display: none !important;
            }
            .print-only-header {
                display: block !important;
            }
            body, .fi-main {
                background: #fff !important;
                color: #000 !important;
            }
        }
        .print-only-header {
            display: none;
        }
    </style>

    {{-- Print-only Report Header --}}
    <div class="print-only-header mb-4 border-b border-gray-300 pb-3">
        <h1 class="text-xl font-bold">DaanAR — Landmark Visit Analytics Report</h1>
        <p class="text-sm text-gray-600">
            Period: <strong>{{ $stats['period_label'] }}</strong> • Generated: {{ now()->format('M d, Y h:i A') }}
        </p>
    </div>

    {{-- Top Controls: Date Range Filter & Export Actions --}}
    <div class="no-print mb-6 flex flex-col gap-3 rounded-xl border border-gray-200 bg-white p-4 shadow-sm dark:border-white/10 dark:bg-gray-900 lg:flex-row lg:items-center lg:justify-between">
        <div class="flex flex-wrap items-center gap-3">
            <div class="flex items-center gap-2">
                <x-heroicon-o-calendar class="h-5 w-5 text-primary-500" />
                <span class="text-sm font-semibold text-gray-700 dark:text-gray-200">Date Period:</span>
            </div>

            <select
                wire:model.live="datePeriod"
                class="rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-900 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-white/15 dark:bg-gray-800 dark:text-white"
            >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
                <option value="custom">Custom Date Range</option>
            </select>

            @if($datePeriod === 'custom')
                <div class="flex flex-wrap items-center gap-2">
                    <input
                        type="date"
                        wire:model.live="startDate"
                        class="rounded-lg border border-gray-300 bg-white px-2.5 py-1.5 text-sm text-gray-900 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-white/15 dark:bg-gray-800 dark:text-white"
                    />
                    <span class="text-xs text-gray-400">to</span>
                    <input
                        type="date"
                        wire:model.live="endDate"
                        class="rounded-lg border border-gray-300 bg-white px-2.5 py-1.5 text-sm text-gray-900 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-white/15 dark:bg-gray-800 dark:text-white"
                    />
                </div>
            @endif

            <span class="rounded-full bg-primary-50 px-2.5 py-1 text-xs font-medium text-primary-700 dark:bg-primary-950 dark:text-primary-300">
                Active: {{ $stats['period_label'] }}
            </span>
        </div>

        <div class="flex flex-wrap items-center gap-2">
            <button
                type="button"
                wire:click="exportCsv"
                class="inline-flex items-center gap-1.5 rounded-lg border border-gray-300 bg-white px-3.5 py-2 text-xs font-semibold text-gray-700 shadow-sm transition hover:bg-gray-50 dark:border-white/15 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
            >
                <x-heroicon-o-arrow-down-tray class="h-4 w-4 text-primary-500" />
                Export CSV
            </button>

            <button
                type="button"
                onclick="window.print()"
                class="inline-flex items-center gap-1.5 rounded-lg bg-primary-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm transition hover:bg-primary-500"
            >
                <x-heroicon-o-printer class="h-4 w-4" />
                Export PDF / Print Report
            </button>
        </div>
    </div>

    {{-- 6 Summary KPI Cards --}}
    <div class="grid grid-cols-1 gap-4 mb-6 sm:grid-cols-2 lg:grid-cols-3">

        {{-- 1. Total Visits (On-Site) --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-success-100 p-2.5 dark:bg-success-900/50">
                    <x-heroicon-o-map-pin class="h-6 w-6 text-success-600 dark:text-success-400" />
                </div>
                <div>
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Total Visits (On-Site)
                    </p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['total_physical_visits']) }}
                    </p>
                    <p class="text-xs text-gray-400">Verified physical foot traffic (GPS ≤ 100m)</p>
                </div>
            </div>
        </div>

        {{-- 2. Today's Visits --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-warning-100 p-2.5 dark:bg-warning-900/50">
                    <x-heroicon-o-calendar-days class="h-6 w-6 text-warning-600 dark:text-warning-400" />
                </div>
                <div>
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Today's Visits
                    </p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['today_physical_visits']) }}
                    </p>
                    <p class="text-xs text-gray-400">On-site visits recorded today</p>
                </div>
            </div>
        </div>

        {{-- 3. Unique Visitors --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-info-100 p-2.5 dark:bg-info-900/50">
                    <x-heroicon-o-users class="h-6 w-6 text-info-600 dark:text-info-400" />
                </div>
                <div>
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Unique Visitors
                    </p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['unique_visitors']) }}
                    </p>
                    <p class="text-xs text-gray-400">Distinct registered mobile users</p>
                </div>
            </div>
        </div>

        {{-- 4. Total AR Views --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-primary-100 p-2.5 dark:bg-primary-900/50">
                    <x-heroicon-o-cube-transparent class="h-6 w-6 text-primary-600 dark:text-primary-400" />
                </div>
                <div>
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Total AR Views
                    </p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['total_ar_views']) }}
                    </p>
                    <p class="text-xs text-gray-400">Virtual 3D / AR model inspections</p>
                </div>
            </div>
        </div>

        {{-- 5. Today's AR Views --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-primary-100 p-2.5 dark:bg-primary-900/50">
                    <x-heroicon-o-sparkles class="h-6 w-6 text-primary-600 dark:text-primary-400" />
                </div>
                <div>
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Today's AR Views
                    </p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['today_ar_views']) }}
                    </p>
                    <p class="text-xs text-gray-400">Virtual AR views recorded today</p>
                </div>
            </div>
        </div>

        {{-- 6. Most Visited Site (Selected Period) --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-warning-100 p-2.5 dark:bg-warning-900/50">
                    <x-heroicon-o-trophy class="h-6 w-6 text-warning-600 dark:text-warning-400" />
                </div>
                <div class="min-w-0">
                    <p class="text-xs font-medium uppercase tracking-wide text-gray-500 dark:text-gray-400">
                        Most Visited Site ({{ $datePeriod === 'all' ? 'All Time' : 'Selected Period' }})
                    </p>
                    <p class="text-base font-bold text-gray-900 dark:text-white truncate" title="{{ $stats['most_visited_site'] }}">
                        {{ Str::limit($stats['most_visited_site'], 28) }}
                    </p>
                    @if($stats['most_visited_physical'] > 0 || $stats['most_visited_ar'] > 0)
                        <p class="text-xs text-gray-400">
                            {{ number_format($stats['most_visited_physical']) }} on-site • {{ number_format($stats['most_visited_ar']) }} AR views
                        </p>
                    @else
                        <p class="text-xs text-gray-400">No visits in period</p>
                    @endif
                </div>
            </div>
        </div>

    </div>

    {{-- Main Landmark Visit Analytics Table --}}
    {{ $this->table }}

</x-filament-panels::page>
