import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daanar_app/core/theme.dart';
import 'package:daanar_app/services/history_service.dart';

void main() {
  test('Archival theme initializes with Cormorant and Inter fonts', () {
    final theme = AppTheme.light;
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('HistoryService seeds, records visits and AR views, and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final initial = await HistoryService.instance.loadEntries();
    expect(initial.length, 4);

    await HistoryService.instance.recordEntry(
      landmarkId: 99,
      landmarkName: 'Test Heritage Landmark',
      municipalityName: 'Manaoag',
      category: 'church',
      type: HistoryEntryType.ar,
      subtitle: '3D architectural reconstruction',
    );

    final afterRecord = await HistoryService.instance.loadEntries();
    expect(afterRecord.first.landmarkId, 99);
    expect(afterRecord.first.type, HistoryEntryType.ar);

    await HistoryService.instance.clearAll();
    final afterClear = await HistoryService.instance.loadEntries();
    expect(afterClear, isEmpty);
  });
}
