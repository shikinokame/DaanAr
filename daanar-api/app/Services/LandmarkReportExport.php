<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Collection;
use OpenSpout\Common\Entity\Cell;
use OpenSpout\Common\Entity\Cell\StringCell;
use OpenSpout\Common\Entity\Row;
use OpenSpout\Common\Entity\Style\Border;
use OpenSpout\Common\Entity\Style\BorderPart;
use OpenSpout\Common\Entity\Style\Style;
use OpenSpout\Writer\AutoFilter;
use OpenSpout\Writer\XLSX\Entity\SheetView;
use OpenSpout\Writer\XLSX\Options;
use OpenSpout\Writer\XLSX\Options\PageOrientation;
use OpenSpout\Writer\XLSX\Options\PageSetup;
use OpenSpout\Writer\XLSX\Options\PaperSize;
use OpenSpout\Writer\XLSX\Writer;

class LandmarkReportExport
{
    public const HEADERS = [
        'Landmark', 'Municipality', 'Category', 'On-Site Visits', 'Unique Visitors',
        'AR Views', 'Unique AR Viewers', 'Map Navigations', 'Last Activity',
    ];

    public function data(Collection $records, string $period, string $filters): array
    {
        $rows = $records->map(fn ($record): array => [
            (string) $record->name,
            $record->municipality?->name ?? 'Pangasinan',
            ucfirst((string) $record->category),
            (int) $record->total_physical_visits,
            (int) $record->unique_visitors,
            (int) $record->viewed_in_ar,
            (int) $record->unique_ar_viewers,
            (int) $record->map_navigations,
            $record->last_visited_at
                ? Carbon::parse($record->last_visited_at)->format('M d, Y h:i A')
                : 'No activity yet',
        ])->values()->all();

        return [
            'title' => 'DaanAR Landmark Visit Analytics Report',
            'period' => $period,
            'filters' => $filters,
            'generated' => now()->format('M d, Y h:i A T'),
            'headers' => self::HEADERS,
            'rows' => $rows,
            'totals' => [
                'landmarks' => count($rows),
                'visits' => array_sum(array_column($rows, 3)),
                'ar_views' => array_sum(array_column($rows, 5)),
                'navigations' => array_sum(array_column($rows, 7)),
            ],
            'note' => 'Unique visitor counts are per landmark. A person visiting multiple landmarks can appear in more than one row.',
        ];
    }

    /** CSV is a flat, importable table; formatting belongs in the Excel export. */
    public function writeCsv($stream, array $report): void
    {
        fwrite($stream, "\xEF\xBB\xBF");
        fputcsv($stream, self::HEADERS, ',', '"', '', "\r\n");
        foreach ($report['rows'] as $row) {
            // Prevent spreadsheet formulas in user-maintained names and categories.
            $safe = array_map(fn ($value) => is_string($value)
                && preg_match('/^[\s\x00-\x1f]*[=+@-]/u', $value)
                    ? "'".$value : $value, $row);
            fputcsv($stream, $safe, ',', '"', '', "\r\n");
        }
    }

    public function writeExcel(string $path, array $report): void
    {
        $options = new Options;
        $options->setPageSetup(new PageSetup(PageOrientation::LANDSCAPE, PaperSize::Letter, 0, 1));
        $options->DEFAULT_ROW_STYLE = (new Style)->setFontName('Calibri')->setFontSize(11);
        foreach ([1, 2, 3, 4, 5, 6] as $row) {
            $options->mergeCells(0, $row, 8, $row);
        }
        $writer = new Writer($options);
        $writer->openToFile($path);
        try {
            $sheet = $writer->getCurrentSheet();
            $sheet->setName('Landmark Analytics');
            foreach ([48, 24, 18, 17, 17, 16, 19, 19, 27] as $column => $width) {
                $sheet->setColumnWidth($width, $column + 1);
            }
            $sheet->setSheetView((new SheetView)->setFreezeRow(9)->setShowGridLines(false));
            $sheet->setPrintTitleRows('1:8');
            $border = new Border(...array_map(
                fn ($side) => new BorderPart($side, 'D9D9D9', Border::WIDTH_THIN),
                [Border::LEFT, Border::RIGHT, Border::TOP, Border::BOTTOM],
            ));
            $title = (new Style)->setFontBold()->setFontSize(17)->setFontColor('FFFFFF')->setBackgroundColor('204536');
            $meta = (new Style)->setShouldWrapText()->setFontColor('333333');
            $writer->addRow($this->row([$report['title']], $title, 32));
            $writer->addRow($this->row(['Date period: '.$report['period']], $meta, 25));
            $writer->addRow($this->row(['Generated: '.$report['generated']], $meta, 25));
            $writer->addRow($this->row(['Filters: '.$report['filters']], $meta, 30));
            $totals = $report['totals'];
            $writer->addRow($this->row([
                "Landmarks: {$totals['landmarks']}    |    On-site visits: {$totals['visits']}    |    AR views: {$totals['ar_views']}    |    Map navigations: {$totals['navigations']}",
            ], (new Style)->setFontBold()->setBackgroundColor('E8EFEA'), 28));
            $writer->addRow($this->row([$report['note']], $meta, 30));
            $writer->addRow(Row::fromValues([]));
            $header = (new Style)->setFontBold()->setFontColor('FFFFFF')->setBackgroundColor('204536')->setShouldWrapText()->setBorder($border);
            $writer->addRow($this->row(self::HEADERS, $header, 34));
            foreach ($report['rows'] as $index => $values) {
                $style = (new Style)->setShouldWrapText()->setCellVerticalAlignment('center')
                    ->setBorder($border)->setBackgroundColor($index % 2 ? 'F0F4F1' : 'FFFFFF');
                $lines = max(2, (int) ceil(mb_strlen($values[0]) / 43), (int) ceil(mb_strlen($values[1]) / 21));
                $writer->addRow($this->row($values, $style, $lines * 16));
            }
            if ($report['rows'] === []) {
                $writer->addRow($this->row(['No landmarks match the selected filters.'], $meta, 28));
            } else {
                $sheet->setAutoFilter(new AutoFilter(0, 8, 8, 8 + count($report['rows'])));
            }
            $writer->addRow($this->row([
                'TOTAL ACTIVITY', '', '', $totals['visits'], '', $totals['ar_views'], '', $totals['navigations'], '',
            ], (new Style)->setFontBold()->setBackgroundColor('E8EFEA')->setBorder($border), 26));
        } finally {
            $writer->close();
        }
    }

    private function row(array $values, Style $style, float $height): Row
    {
        // Explicit string cells keep even names beginning with '=' as plain text.
        $cells = array_map(fn ($value) => is_string($value)
            ? new StringCell($value, null) : Cell::fromValue($value), $values);

        return (new Row($cells, $style))->setHeight($height);
    }
}
