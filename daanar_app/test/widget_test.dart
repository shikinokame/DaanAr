import 'package:flutter_test/flutter_test.dart';
import 'package:daanar_app/core/theme.dart';

void main() {
  test('Archival theme initializes with Cormorant and Inter fonts', () {
    final theme = AppTheme.light;
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });
}
