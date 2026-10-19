<x-filament-panels::page>

    @php $stats = $this->getStatsData(); @endphp

    <style>
        .daan-toolbar {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            padding: 16px 20px;
            background: #14120F;
            border: 1px solid rgba(243, 239, 230, 0.10);
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .daan-toolbar-group {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 12px;
        }
        .daan-select, .daan-date-input {
            background: #0C0B09;
            border: 1px solid rgba(243, 239, 230, 0.15);
            color: #F3EFE6;
            border-radius: 5px;
            padding: 7px 12px;
            font-size: 13px;
            font-family: 'Plus Jakarta Sans', sans-serif;
        }
        .daan-select:focus, .daan-date-input:focus {
            outline: none;
            border-color: #D4A056;
        }
        .daan-period-badge {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.08em;
            padding: 5px 12px;
            border-radius: 4px;
            background: rgba(212, 160, 86, 0.10);
            border: 1px solid rgba(212, 160, 86, 0.35);
            color: #D4A056;
        }
        .daan-btn-secondary {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 14px;
            border-radius: 5px;
            background: #1B1814;
            border: 1px solid rgba(243, 239, 230, 0.14);
            color: #F3EFE6;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }
        .daan-btn-secondary:hover {
            border-color: #D4A056;
            color: #D4A056;
        }
        .daan-btn-primary {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            border-radius: 5px;
            background: #D4A056;
            border: 1px solid #D4A056;
            color: #0C0B09;
            font-size: 12px;
            font-weight: 700;
            cursor: pointer;
            transition: all 0.2s;
        }
        .daan-btn-primary:hover {
            background: #E2B26B;
        }

        /* ── 3x2 Architectural KPI Grid (Fixes vertical stacking) ── */
        .daan-kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .daan-kpi-card {
            background: #14120F;
            border: 1px solid rgba(243, 239, 230, 0.10);
            border-radius: 8px;
            padding: 20px;
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 16px;
            transition: border-color 0.2s;
        }
        .daan-kpi-card:hover {
            border-color: rgba(212, 160, 86, 0.4);
        }
        .daan-kpi-label {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            color: #9E9587;
            margin-bottom: 6px;
        }
        .daan-kpi-value {
            font-family: 'Cormorant Garamond', Georgia, serif;
            font-size: 34px;
            font-weight: 700;
            line-height: 1.05;
            color: #F3EFE6;
            margin-bottom: 6px;
        }
        .daan-kpi-value.text-truncate {
            font-size: 24px;
            line-height: 1.2;
        }
        .daan-kpi-sub {
            font-size: 12px;
            color: #9E9587;
        }
        .daan-kpi-icon {
            width: 40px;
            height: 40px;
            border-radius: 6px;
            background: rgba(212, 160, 86, 0.08);
            border: 1px solid rgba(212, 160, 86, 0.28);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #D4A056;
            flex-shrink: 0;
        }

        /* ── Clean Black-on-White Print / PDF Override ─────────── */
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
            body.fi-body, body, .fi-main, .fi-page {
                background: #ffffff !important;
                background-image: none !important;
                color: #000000 !important;
            }
            .daan-kpi-grid {
                grid-template-columns: repeat(3, 1fr) !important;
                gap: 10px !important;
            }
            .daan-kpi-card,
            .fi-ta-ctn,
            .fi-ta-header-cell {
                background: #ffffff !important;
                border: 1px solid #d1d5db !important;
                box-shadow: none !important;
                color: #000000 !important;
            }
            .daan-kpi-value,
            .fi-ta-text-item-label {
                color: #000000 !important;
            }
            .daan-kpi-label,
            .daan-kpi-sub,
            .fi-ta-header-cell {
                color: #374151 !important;
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
    <div class="daan-toolbar no-print">
        <div class="daan-toolbar-group">
            <div style="display:flex; align-items:center; gap:8px; color:#D4A056;">
                <x-heroicon-o-calendar class="h-5 w-5" />
                <span style="font-family:'JetBrains Mono', monospace; font-size:11px; text-transform:uppercase; letter-spacing:0.1em; color:#F3EFE6;">
                    Telemetry Window:
                </span>
            </div>

            <select wire:model.live="datePeriod" class="daan-select">
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
                <option value="custom">Custom Date Range</option>
            </select>

            @if($datePeriod === 'custom')
                <div class="daan-toolbar-group">
                    <input type="date" wire:model.live="startDate" class="daan-date-input" />
                    <span style="font-size:12px; color:#9E9587;">to</span>
                    <input type="date" wire:model.live="endDate" class="daan-date-input" />
                </div>
            @endif

            <span class="daan-period-badge">
                Active: {{ $stats['period_label'] }}
            </span>
        </div>

        <div class="daan-toolbar-group">
            <button type="button" wire:click="exportCsv" class="daan-btn-secondary">
                <x-heroicon-o-arrow-down-tray class="h-4 w-4" style="color:#D4A056;" />
                <span>Export CSV</span>
            </button>

            <button type="button" onclick="window.print()" class="daan-btn-primary">
                <x-heroicon-o-printer class="h-4 w-4" />
                <span>Export PDF / Print</span>
            </button>
        </div>
    </div>

    {{-- 6 Summary KPI Cards in a Clean 3x2 Grid --}}
    <div class="daan-kpi-grid">

        {{-- 1. Total Visits (On-Site) --}}
        <div class="daan-kpi-card">
            <div>
                <p class="daan-kpi-label">01 / Total Visits (On-Site)</p>
                <p class="daan-kpi-value">{{ number_format($stats['total_physical_visits']) }}</p>
                <p class="daan-kpi-sub">Verified physical foot traffic (GPS ≤ 100m)</p>
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-map-pin class="h-5 w-5" />
            </div>
        </div>

        {{-- 2. Today's Visits --}}
        <div class="daan-kpi-card">
            <div>
                <p class="daan-kpi-label">02 / Today's Visits</p>
                <p class="daan-kpi-value">{{ number_format($stats['today_physical_visits']) }}</p>
                <p class="daan-kpi-sub">On-site visits recorded today</p>
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-calendar-days class="h-5 w-5" />
            </div>
        </div>

        {{-- 3. Unique Visitors --}}
        <div class="daan-kpi-card">
            <div>
                <p class="daan-kpi-label">03 / Unique Visitors</p>
                <p class="daan-kpi-value">{{ number_format($stats['unique_visitors']) }}</p>
                <p class="daan-kpi-sub">Distinct registered mobile users</p>
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-users class="h-5 w-5" />
            </div>
        </div>

        {{-- 4. Total AR Views --}}
        <div class="daan-kpi-card">
            <div>
                <p class="daan-kpi-label">04 / Total AR Views</p>
                <p class="daan-kpi-value">{{ number_format($stats['total_ar_views']) }}</p>
                <p class="daan-kpi-sub">Virtual 3D / AR model inspections</p>
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-cube-transparent class="h-5 w-5" />
            </div>
        </div>

        {{-- 5. Today's AR Views --}}
        <div class="daan-kpi-card">
            <div>
                <p class="daan-kpi-label">05 / Today's AR Views</p>
                <p class="daan-kpi-value">{{ number_format($stats['today_ar_views']) }}</p>
                <p class="daan-kpi-sub">Virtual AR views recorded today</p>
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-sparkles class="h-5 w-5" />
            </div>
        </div>

        {{-- 6. Most Visited Site --}}
        <div class="daan-kpi-card">
            <div style="min-width: 0;">
                <p class="daan-kpi-label">06 / Top Heritage Site</p>
                <p class="daan-kpi-value text-truncate" title="{{ $stats['most_visited_site'] }}">
                    {{ Str::limit($stats['most_visited_site'], 26) }}
                </p>
                @if($stats['most_visited_physical'] > 0 || $stats['most_visited_ar'] > 0)
                    <p class="daan-kpi-sub">
                        {{ number_format($stats['most_visited_physical']) }} on-site • {{ number_format($stats['most_visited_ar']) }} AR views
                    </p>
                @else
                    <p class="daan-kpi-sub">No visits in selected window</p>
                @endif
            </div>
            <div class="daan-kpi-icon">
                <x-heroicon-o-trophy class="h-5 w-5" />
            </div>
        </div>

    </div>

    {{-- Main Landmark Visit Analytics Table --}}
    {{ $this->table }}

</x-filament-panels::page>
