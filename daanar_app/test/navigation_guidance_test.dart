import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:daanar_app/models/route_result.dart';
import 'package:daanar_app/services/navigation_guidance.dart';
import 'package:daanar_app/widgets/turn_guidance_banner.dart';

// North 111 m, east 111 m, then north 111 m. Sparse vertices deliberately
// exercise projection on segments rather than snapping to the nearest corner.
const route = RouteResult(
  points: [
    LatLng(0, 0),
    LatLng(.001, 0),
    LatLng(.001, .001),
    LatLng(.002, .001),
  ],
  distanceMetres: 333,
  durationSeconds: 240,
  steps: [
    RouteStep(
      instruction: 'Start along the road',
      distanceMetres: 111,
      durationSeconds: 80,
      wayPointStart: 0,
      wayPointEnd: 1,
      maneuver: RouteManeuver.depart,
    ),
    RouteStep(
      instruction: 'Turn right onto First Street',
      distanceMetres: 111,
      durationSeconds: 80,
      wayPointStart: 1,
      wayPointEnd: 2,
      maneuver: RouteManeuver.right,
    ),
    RouteStep(
      instruction: 'Turn left onto Second Street',
      distanceMetres: 111,
      durationSeconds: 80,
      wayPointStart: 2,
      wayPointEnd: 3,
      maneuver: RouteManeuver.left,
    ),
    RouteStep(
      instruction: 'Arrive at your destination',
      distanceMetres: 0,
      durationSeconds: 0,
      wayPointStart: 3,
      maneuver: RouteManeuver.arrive,
    ),
  ],
);

void main() {
  test('street names do not become false left/right/arrival instructions', () {
    expect(
      RouteManeuver.fromInstruction('Continue onto Wright Street'),
      RouteManeuver.straight,
    );
    expect(
      RouteManeuver.fromInstruction('Continue onto Left Bank Road'),
      RouteManeuver.straight,
    );
    expect(
      RouteManeuver.fromInstruction('Continue towards Destination Road'),
      RouteManeuver.straight,
    );
    expect(
      RouteManeuver.fromInstruction('Head along Wright Street'),
      RouteManeuver.depart,
    );
    expect(
      RouteManeuver.fromInstruction('Turn left onto Wright Street'),
      RouteManeuver.left,
    );
  });
  test('backtracking increases remaining road distance', () {
    final g = NavigationGuidance(route);
    final ahead = g.at(const LatLng(.001, .0008));
    final back = g.at(const LatLng(.001, .0003), previousAlong: ahead.along);
    expect(back.remaining, greaterThan(ahead.remaining + 40));
    expect(back.step!.direction, RouteManeuver.left);
  });
  test('continuity distinguishes the end from the start of a loop', () {
    const loop = RouteResult(
      points: [
        LatLng(0, 0),
        LatLng(.001, 0),
        LatLng(.001, .001),
        LatLng(0, .001),
        LatLng(0, 0),
      ],
      distanceMetres: 444,
      durationSeconds: 300,
    );
    final g = NavigationGuidance(loop);
    expect(g.at(const LatLng(0, 0)).remaining, greaterThan(400));
    final end = g.at(const LatLng(0, 0), previousAlong: 440);
    expect(end.remaining, lessThan(1));
    expect(end.etaLabel, 'Arrived');
  });
  test(
    'route geometry without instructions still provides look-ahead and distance',
    () {
      final g = NavigationGuidance(
        RouteResult(
          points: route.points,
          distanceMetres: 333,
          durationSeconds: 240,
        ),
      );
      final p = g.at(const LatLng(.0005, 0));
      expect(p.step, isNull);
      expect(p.lookAhead!.latitude, greaterThan(.0005));
      expect(p.remaining, greaterThan(250));
    },
  );
  test('distance to turn and remaining distance follow the road', () {
    final p = NavigationGuidance(route).at(const LatLng(.0005, 0));
    expect(p.step!.direction, RouteManeuver.right);
    expect(p.distanceToTurn, closeTo(55.6, 1));
    expect(p.remaining, closeTo(278, 2));
    expect(p.deviation, closeTo(0, .1));
    expect(p.then!.direction, RouteManeuver.left);
  });
  test('keeps turn at corner and advances after crossing it', () {
    final g = NavigationGuidance(route);
    expect(g.at(const LatLng(.001, 0)).step!.direction, RouteManeuver.right);
    final p = g.at(const LatLng(.001, .0002));
    expect(p.step!.direction, RouteManeuver.left);
    expect(p.distanceToTurn, closeTo(89, 1));
    expect(p.secondsRemaining, lessThan(240));
  });
  test('a fix halfway down a long segment is not off route', () {
    expect(
      NavigationGuidance(route).at(const LatLng(.0005, .00001)).offRoute,
      false,
    );
    expect(
      NavigationGuidance(route).at(const LatLng(.0005, -.001)).offRoute,
      true,
    );
  });
  test('arrival does not revert to first route instruction', () {
    final p = NavigationGuidance(route).at(const LatLng(.002, .001));
    expect(p.step!.direction, RouteManeuver.arrive);
    expect(p.remaining, closeTo(0, .1));
    expect(p.then, isNull);
  });
  test('cached steps without waypoint indices progress by road distance', () {
    final cached = RouteResult(
      points: route.points,
      distanceMetres: 333,
      durationSeconds: 240,
      steps: route.steps
          .map(
            (s) => RouteStep(
              instruction: s.instruction,
              distanceMetres: s.distanceMetres,
              durationSeconds: s.durationSeconds,
            ),
          )
          .toList(),
    );
    expect(
      NavigationGuidance(cached).at(const LatLng(.001, .0002)).step!.direction,
      RouteManeuver.left,
    );
  });
  test(
    'empty and duplicate-point routes are handled without invalid arithmetic',
    () {
      const empty = RouteResult(
        points: [],
        distanceMetres: 0,
        durationSeconds: 0,
      );
      expect(NavigationGuidance(empty).at(const LatLng(0, 0)).offRoute, true);
      const duplicate = RouteResult(
        points: [LatLng(0, 0), LatLng(0, 0)],
        distanceMetres: 0,
        durationSeconds: 0,
      );
      expect(
        NavigationGuidance(duplicate).at(const LatLng(0, 0)).remaining.isFinite,
        true,
      );
    },
  );
  testWidgets('banner shows the actual arrow and distance on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurnGuidanceBanner(
            progress: NavigationGuidance(route).at(const LatLng(.0005, 0)),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.turn_right_rounded), findsOneWidget);
    expect(find.text('In 56 m'), findsOneWidget);
    expect(find.text('Then Turn left onto Second Street'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rerouting hides the obsolete turn instruction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurnGuidanceBanner(
            rerouting: true,
            progress: NavigationGuidance(route).at(const LatLng(.0005, 0)),
          ),
        ),
      ),
    );
    expect(find.text('Updating route'), findsOneWidget);
    expect(find.byIcon(Icons.turn_right_rounded), findsNothing);
    expect(find.text('Turn right onto First Street'), findsNothing);
  });

  testWidgets(
    'all maneuver arrows render without overflow with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final maneuver in RouteManeuver.values) {
        final step = RouteStep(
          instruction: 'Continue using the road at the next junction',
          distanceMetres: 100,
          durationSeconds: 60,
          maneuver: maneuver,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: TurnGuidanceBanner(
                  progress: NavigationProgress(
                    along: 10,
                    remaining: 300,
                    secondsRemaining: 240,
                    deviation: 0,
                    distanceToTurn: 120,
                    step: step,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          find.byIcon(TurnGuidanceBanner.iconFor(maneuver)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'off-route and missing-GPS displays do not keep old turn guidance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnGuidanceBanner(
              progress: NavigationGuidance(
                route,
              ).at(const LatLng(.0005, -.001)),
            ),
          ),
        ),
      );
      expect(find.text('Off route'), findsOneWidget);
      expect(find.byIcon(Icons.turn_right_rounded), findsNothing);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TurnGuidanceBanner())),
      );
      expect(find.text('Finding route'), findsOneWidget);
      expect(find.text('Waiting for GPS and road directions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
