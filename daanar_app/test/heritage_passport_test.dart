import 'dart:convert';

import 'package:daanar_app/providers/landmark_providers.dart';
import 'package:daanar_app/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Passport stamps visits and counts distinct landmarks', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 15, 12);
    SharedPreferences.setMockInitialValues({
      'daanar_field_history_v2': jsonEncode([
        {
          'landmark_id': 3,
          'landmark_name': 'Manaoag Basilica',
          'type': 'visit',
          'timestamp': now.toIso8601String(),
        },
        {
          'landmark_id': 3,
          'landmark_name': 'Manaoag Basilica',
          'type': 'visit',
          'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
        {
          'landmark_id': 7,
          'landmark_name': 'San Jacinto Monument',
          'type': 'ar',
          'timestamp': now.toIso8601String(),
        },
      ]),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          landmarkListProvider.overrideWith(
            (ref) async => const LandmarkResult(
              landmarks: [],
              fromCache: true,
              catalogTotal: 20,
            ),
          ),
        ],
        child: const MaterialApp(home: FieldHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heritage Passport'), findsOneWidget);
    expect(find.text('1 of 20 Pangasinan landmarks visited'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1 / 20);
    expect(find.text('VISITED'), findsNWidgets(2));

    await tester.tap(find.text('AR VIEWED'));
    await tester.pumpAndSettle();
    expect(find.text('San Jacinto Monument'), findsOneWidget);
    expect(find.text('VISITED'), findsNothing);
    expect(find.text('1 of 20 Pangasinan landmarks visited'), findsOneWidget);
  });
}
