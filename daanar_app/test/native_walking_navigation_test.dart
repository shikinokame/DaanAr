import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:daanar_app/models/route_result.dart';
import 'package:daanar_app/services/native_walking_navigation.dart';

void main() {
  const points = [LatLng(16, 120), LatLng(16.001, 120.002)];
  test('native route handoff keeps coordinate order and maneuver indexes', () {
    final result = NativeWalkingNavigation.encodeRoute(
      const RouteResult(
        points: points,
        distanceMetres: 200,
        durationSeconds: 180,
        travelMode: 'WALK',
        warnings: ['Use the pedestrian path.'],
        steps: [
          RouteStep(
            instruction: 'Turn right',
            distanceMetres: 100,
            durationSeconds: 90,
            wayPointStart: 1,
          ),
        ],
      ),
    );
    expect(result['points'], [
      [16.0, 120.0],
      [16.001, 120.002],
    ]);
    expect(result['steps'], [
      {'index': 1, 'instruction': 'Turn right'},
    ]);
    expect(result['warnings'], ['Use the pedestrian path.']);
  });
  test('driving route cannot silently become walking AR', () {
    expect(
      () => NativeWalkingNavigation.encodeRoute(
        const RouteResult(
          points: points,
          distanceMetres: 200,
          durationSeconds: 50,
          travelMode: 'DRIVE',
        ),
      ),
      throwsFormatException,
    );
  });
}
