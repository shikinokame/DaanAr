<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $report['title'] }}</title>
    <style>
        @page { size: landscape; margin: 12mm; }
        * { box-sizing: border-box; }
        body { margin: 0; background: white; color: #18261f; font: 12px Arial, sans-serif; }
        main { max-width: 1400px; margin: 24px auto; padding: 0 20px; }
        h1 { margin: 0 0 10px; font-size: 23px; }
        .brand { color: #204536; font-size: 12px; font-weight: bold; letter-spacing: 2px; margin-bottom: 8px; }
        .metadata { line-height: 1.6; color: #37463d; overflow-wrap: anywhere; }
        .summary { display: flex; gap: 12px; margin: 20px 0; }
        .summary div { flex: 1; border: 1px solid #b8c8be; padding: 12px; }
        .summary strong { display: block; font-size: 22px; margin-bottom: 4px; }
        table { width: 100%; border-collapse: collapse; table-layout: fixed; }
        th, td { border: 1px solid #b8c8be; padding: 8px 6px; vertical-align: top; overflow-wrap: anywhere; }
        th { background: #204536; color: white; text-align: left; font-size: 11px; }
        tbody tr:nth-child(even) { background: #f0f4f1; }
        .number { text-align: center; font-variant-numeric: tabular-nums; }
        tfoot { font-weight: bold; background: #e8efea; }
        .note { margin-top: 14px; line-height: 1.6; color: #46544b; }
        .tools { display: flex; gap: 12px; align-items: center; padding: 12px; margin-bottom: 20px; background: #f0f4f1; }
        button { padding: 10px 16px; background: #204536; color: white; border: 0; border-radius: 4px; cursor: pointer; }
        @media print {
            .tools { display: none; }
            main { max-width: none; margin: 0; padding: 0; }
            body { font-size: 9pt; }
            h1 { font-size: 18pt; }
            th { font-size: 8pt; }
            th, td { padding: 6px 4px; }
            thead { display: table-header-group; }
            tfoot { display: table-row-group; }
            tr, .summary { break-inside: avoid; }
            th { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
        }
    </style>
</head>
<body>
<main>
    <div class="tools">
        <button type="button" onclick="window.print()">Print / Save as PDF</button>
        <span>Select Save as PDF in the print dialog to download this report.</span>
    </div>
    <div class="brand">DAANAR HERITAGE ANALYTICS</div>
    <h1>{{ $report['title'] }}</h1>
    <div class="metadata">
        <div><strong>Date period:</strong> {{ $report['period'] }}</div>
        <div><strong>Filters:</strong> {{ $report['filters'] }}</div>
        <div><strong>Generated:</strong> {{ $report['generated'] }}</div>
    </div>
    <div class="summary">
        @foreach (['landmarks' => 'Landmarks', 'visits' => 'On-Site Visits', 'ar_views' => 'AR Views', 'navigations' => 'Map Navigations'] as $key => $label)
            <div><strong>{{ number_format($report['totals'][$key]) }}</strong>{{ $label }}</div>
        @endforeach
    </div>
    <table aria-label="Landmark visit analytics">
        <colgroup>
            <col style="width:24%"><col style="width:12%"><col style="width:9%">
            <col style="width:8%"><col style="width:8%"><col style="width:7%">
            <col style="width:9%"><col style="width:9%"><col style="width:14%">
        </colgroup>
        <thead><tr>@foreach ($report['headers'] as $heading)<th>{{ $heading }}</th>@endforeach</tr></thead>
        <tbody>
        @forelse ($report['rows'] as $row)
            <tr>@foreach ($row as $index => $value)<td @class(['number' => $index >= 3 && $index <= 7])>{{ is_int($value) ? number_format($value) : $value }}</td>@endforeach</tr>
        @empty
            <tr><td colspan="9">No landmarks match the selected filters.</td></tr>
        @endforelse
        </tbody>
        <tfoot><tr>
            <td colspan="3">Total activity</td>
            <td class="number">{{ number_format($report['totals']['visits']) }}</td><td></td>
            <td class="number">{{ number_format($report['totals']['ar_views']) }}</td><td></td>
            <td class="number">{{ number_format($report['totals']['navigations']) }}</td><td></td>
        </tr></tfoot>
    </table>
    <p class="note">{{ $report['note'] }}<br>All rows matching the active filters are included, regardless of dashboard pagination. On-site visits, AR views, and map navigations are separate activity counts.</p>
</main>
</body>
</html>
