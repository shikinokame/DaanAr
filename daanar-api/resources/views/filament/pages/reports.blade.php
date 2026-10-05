<x-filament-panels::page>

    {{-- Summary Stats Cards --}}
    @php $stats = $this->getStatsData(); @endphp

    <div class="grid grid-cols-1 gap-4 mb-6 sm:grid-cols-2 lg:grid-cols-4">

        {{-- Total Visits --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-primary-100 p-2 dark:bg-primary-900">
                    <x-heroicon-o-eye class="h-6 w-6 text-primary-600 dark:text-primary-400" />
                </div>
                <div>
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Total Visits</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['total_visits']) }}
                    </p>
                </div>
            </div>
        </div>

        {{-- Unique Visitors --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-success-100 p-2 dark:bg-success-900">
                    <x-heroicon-o-users class="h-6 w-6 text-success-600 dark:text-success-400" />
                </div>
                <div>
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Unique Devices</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['unique_devices']) }}
                    </p>
                </div>
            </div>
        </div>

        {{-- Today's Visits --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-warning-100 p-2 dark:bg-warning-900">
                    <x-heroicon-o-calendar-days class="h-6 w-6 text-warning-600 dark:text-warning-400" />
                </div>
                <div>
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Today's Visits</p>
                    <p class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($stats['today_visits']) }}
                    </p>
                </div>
            </div>
        </div>

        {{-- Most Popular Landmark --}}
        <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm dark:border-white/10 dark:bg-gray-900">
            <div class="flex items-center gap-3">
                <div class="rounded-lg bg-info-100 p-2 dark:bg-info-900">
                    <x-heroicon-o-star class="h-6 w-6 text-info-600 dark:text-info-400" />
                </div>
                <div class="min-w-0">
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Most Visited</p>
                    <p class="text-sm font-bold text-gray-900 dark:text-white truncate" title="{{ $stats['top_landmark'] }}">
                        {{ Str::limit($stats['top_landmark'], 24) }}
                    </p>
                    @if($stats['top_landmark_ct'] > 0)
                        <p class="text-xs text-gray-400">{{ number_format($stats['top_landmark_ct']) }} visits</p>
                    @endif
                </div>
            </div>
        </div>

    </div>

    {{-- Main Table --}}
    {{ $this->table }}

</x-filament-panels::page>
