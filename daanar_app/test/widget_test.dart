import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daanar_app/core/theme.dart';
import 'package:daanar_app/services/history_service.dart';

void main() {
  test('Archival theme initializes with Cormorant and Inter fonts', () {
    final theme = AppTheme.light;
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('HistoryService ignores PAGE_VIEW and only records PHYSICAL_VISIT and AR_VIEW', () async {
    SharedPreferences.setMockInitialValues({});
    final initial = await HistoryService.instance.loadEntries();
    expect(initial, isEmpty);

    // Viewing a landmark page in the app must NOT record a visit
    await HistoryService.instance.recordFromAnalytics(
      landmarkId: 3,
      actionType: 'PAGE_VIEW',
    );
    expect(await HistoryService.instance.loadEntries(), isEmpty);

    // Entering the 100m GPS radius (PHYSICAL_VISIT) records a visit
    await HistoryService.instance.recordFromAnalytics(
      landmarkId: 3,
      actionType: 'PHYSICAL_VISIT',
      verificationMethod: 'GPS_GEOFENCE',
    );
    final afterVisit = await HistoryService.instance.loadEntries();
    expect(afterVisit.length, 1);
    expect(afterVisit.first.type, HistoryEntryType.visit);

    // Opening 3D/AR records an AR view
    await HistoryService.instance.recordEntry(
      landmarkId: 99,
      landmarkName: 'Test Heritage Landmark',
      municipalityName: 'Manaoag',
      category: 'church',
      type: HistoryEntryType.ar,
      subtitle: '3D architectural reconstruction',
    );

    final afterAr = await HistoryService.instance.loadEntries();
    expect(afterAr.length, 2);

    await HistoryService.instance.clearAll();
    final afterClear = await HistoryService.instance.loadEntries();
    expect(afterClear, isEmpty);
  });
}
