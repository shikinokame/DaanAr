<?php

namespace Tests\Feature;

use App\Filament\Pages\Reports;
use App\Models\User;
use App\Services\LandmarkReportExport;
use Filament\Facades\Filament;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Livewire\Livewire;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;
use ZipArchive;

class ReportExportTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // A fresh in-memory connection: never run migrations against local or live data.
        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
        DB::purge('sqlite');
        Schema::create('municipalities', function (Blueprint $table) {
            $table->id();
            $table->string('name');
        });
        Schema::create('landmarks', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('municipality_id');
            $table->string('name');
            $table->string('category');
        });
        Schema::create('landmark_visits', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('landmark_id');
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('device_id')->nullable();
            $table->string('action_type');
            $table->timestamp('visited_at')->nullable();
            $table->timestamps();
        });
        DB::table('municipalities')->insert([
            ['id' => 1, 'name' => 'Dagupan City'], ['id' => 2, 'name' => 'Manaoag'],
        ]);
        for ($id = 1; $id <= 26; $id++) {
            DB::table('landmarks')->insert([
                'id' => $id, 'name' => $id === 1 ? 'San Juan Church' : 'Heritage Landmark '.$id,
                'municipality_id' => $id <= 13 ? 1 : 2,
                'category' => $id <= 5 ? 'church' : 'historical',
            ]);
        }
        foreach (['PHYSICAL_VISIT', 'AR_VIEW', 'MAP_NAV'] as $action) {
            DB::table('landmark_visits')->insert([
                'landmark_id' => 1, 'user_id' => 10, 'action_type' => $action,
                'visited_at' => now(), 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
        DB::table('landmark_visits')->insert([
            'landmark_id' => 1, 'user_id' => 11, 'action_type' => 'PHYSICAL_VISIT',
            'visited_at' => now()->subMonth(), 'created_at' => now()->subMonth(), 'updated_at' => now()->subMonth(),
        ]);
        $this->actingAs((new User)->forceFill(['id' => 999, 'name' => 'Test Admin', 'role' => 'admin', 'status' => 'Active']));
        Filament::setCurrentPanel(Filament::getPanel('admin'));
    }

    public function test_print_includes_all_rows_not_only_the_current_table_page(): void
    {
        $page = Livewire::test(Reports::class)->assertSuccessful();
        $html = $page->instance()->printReport();
        $this->assertStringContainsString('San Juan Church', $html);
        $this->assertStringContainsString('Heritage Landmark 26', $html);
        $this->assertStringContainsString('All Time', $html);
        $this->assertStringContainsString('size: landscape', $html);
        $this->assertStringNotContainsString('fi-sidebar', $html);
        $this->assertSame(26, substr_count($html, '<tr><td class="">'));
    }

    public function test_exports_honor_date_municipality_category_and_search_filters(): void
    {
        $page = Livewire::test(Reports::class)
            ->set('datePeriod', 'today')
            ->filterTable('municipality_id', 1)
            ->filterTable('category', 'church')
            ->searchTable('San Juan');
        $html = $page->instance()->printReport();
        $this->assertStringContainsString('Municipality: Dagupan City | Category: Church | Search: San Juan', $html);
        $this->assertStringContainsString('San Juan Church', $html);
        $this->assertStringNotContainsString('Heritage Landmark 2', $html);
        $response = $page->instance()->exportCsv();
        ob_start();
        $response->sendContent();
        $csv = ob_get_clean();
        $lines = preg_split('/\r\n/', trim(substr($csv, 3)));
        $this->assertCount(2, $lines);
        $values = str_getcsv($lines[1], ',', '"', '');
        $this->assertSame('San Juan Church', $values[0]);
        $this->assertSame(['1', '1', '1', '1', '1'], array_slice($values, 3, 5));
    }

    public function test_empty_report_contains_an_explicit_message(): void
    {
        $page = Livewire::test(Reports::class)->searchTable('NoSuchLandmark');
        $html = $page->instance()->printReport();
        $this->assertStringContainsString('No landmarks match the selected filters.', $html);
    }

    public function test_virtual_activity_does_not_count_as_an_on_site_visitor(): void
    {
        DB::table('landmark_visits')->where('action_type', 'PHYSICAL_VISIT')->delete();

        $stats = Livewire::test(Reports::class)->instance()->getStatsData();

        $this->assertSame(0, $stats['total_physical_visits']);
        $this->assertSame(0, $stats['unique_visitors']);
        $this->assertSame(1, $stats['total_ar_views']);
        $this->assertSame(1, $stats['unique_ar_viewers']);
    }

    public function test_excel_is_a_styled_workbook_with_all_rows_and_numeric_counts(): void
    {
        $response = Livewire::test(Reports::class)->instance()->exportExcel();
        $path = $response->getFile()->getPathname();
        try {
            $zip = new ZipArchive;
            $this->assertTrue($zip->open($path));
            $sheet = $zip->getFromName('xl/worksheets/sheet1.xml');
            $styles = $zip->getFromName('xl/styles.xml');
            $this->assertStringContainsString('Heritage Landmark 26', $sheet);
            $this->assertStringContainsString('width="48"', $sheet);
            $this->assertStringContainsString('A1:I1', $sheet);
            $this->assertStringContainsString('topLeftCell="A9"', $sheet);
            $this->assertStringContainsString('A8:I34', $sheet);
            $this->assertStringContainsString('wrapText="1"', $styles);
            $this->assertStringContainsString('<v>2</v>', $sheet);
            $zip->close();
            $this->assertStringContainsString('.xlsx', $response->headers->get('Content-Disposition'));
        } finally {
            @unlink($path);
        }
    }

    public function test_csv_quotes_names_and_neutralizes_formulas_and_print_escapes_html(): void
    {
        DB::table('landmarks')->where('id', 1)->update(['name' => '=1+1,"San Juan" <script>alert(1)</script>']);
        $page = Livewire::test(Reports::class);
        $response = $page->instance()->exportCsv();
        ob_start();
        $response->sendContent();
        $csv = ob_get_clean();
        $stream = fopen('php://temp', 'w+');
        fwrite($stream, substr($csv, 3));
        rewind($stream);
        $this->assertSame(LandmarkReportExport::HEADERS, fgetcsv($stream, escape: ''));
        $this->assertSame('\'=1+1,"San Juan" <script>alert(1)</script>', fgetcsv($stream, escape: '')[0]);
        fclose($stream);
        $html = $page->instance()->printReport();
        $this->assertStringNotContainsString('<script>alert(1)</script>', $html);
        $this->assertStringContainsString('&lt;script&gt;', $html);
        $response = $page->instance()->exportExcel();
        $path = $response->getFile()->getPathname();
        try {
            $zip = new ZipArchive;
            $zip->open($path);
            $this->assertStringNotContainsString('<f>', $zip->getFromName('xl/worksheets/sheet1.xml'));
            $zip->close();
        } finally {
            @unlink($path);
        }
    }

    public function test_mobile_user_cannot_export_admin_reports(): void
    {
        $this->actingAs((new User)->forceFill(['id' => 998, 'role' => User::ROLE_NORMAL_USER, 'status' => 'Active']));
        $this->expectException(HttpException::class);
        (new Reports)->printReport();
    }

    public function test_custom_date_range_and_sort_order_are_preserved(): void
    {
        $page = Livewire::test(Reports::class)
            ->set('datePeriod', 'custom')
            ->set('startDate', now()->subMonth()->toDateString())
            ->set('endDate', now()->subMonth()->toDateString())
            ->sortTable('name', 'desc');
        $response = $page->instance()->exportCsv();
        ob_start();
        $response->sendContent();
        $csv = ob_get_clean();
        $stream = fopen('php://temp', 'w+');
        fwrite($stream, substr($csv, 3));
        rewind($stream);
        fgetcsv($stream, escape: '');
        $first = fgetcsv($stream, escape: '');
        fclose($stream);
        $this->assertSame('San Juan Church', $first[0]);
        $this->assertSame(['1', '1', '0', '0', '0'], array_slice($first, 3, 5));
        $this->assertStringContainsString('Custom (', $page->instance()->printReport());
    }

    public function test_livewire_downloads_have_real_file_contents(): void
    {
        DB::table('landmarks')->where('id', 26)->update([
            'name' => 'Santuario de San Juan Evangelista and Historical Heritage Conservation Complex',
        ]);
        $page = Livewire::test(Reports::class)->call('exportExcel')->assertFileDownloaded();
        $workbook = base64_decode($page->effects['download']['content'], true);
        $this->assertStringStartsWith('PK', $workbook);
        $this->assertGreaterThan(3000, strlen($workbook));
        $page->call('exportCsv')->assertFileDownloaded();
        $csv = base64_decode($page->effects['download']['content'], true);
        $this->assertStringStartsWith("\xEF\xBB\xBF", $csv);
        $page->call('printReport');
        $html = $page->effects['returns'][0];
        $this->assertStringContainsString('Santuario de San Juan Evangelista', $html);
        // Optional visual fixtures contain only the synthetic data created above.
        if ($directory = getenv('DAANAR_EXPORT_QA_DIR')) {
            if (! is_dir($directory)) {
                mkdir($directory, 0777, true);
            }
            file_put_contents($directory.'/report.xlsx', $workbook);
            file_put_contents($directory.'/report.csv', $csv);
            file_put_contents($directory.'/report.html', $html);
        }
    }
}
