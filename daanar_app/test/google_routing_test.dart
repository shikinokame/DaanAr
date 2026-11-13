import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:daanar_app/models/route_result.dart';
import 'package:daanar_app/models/transport_mode.dart';
import 'package:daanar_app/services/navigation_guidance.dart';
import 'package:daanar_app/services/route_refresh_policy.dart';
import 'package:daanar_app/services/routing_service.dart';
import 'package:daanar_app/widgets/turn_guidance_banner.dart';

Map<String, dynamic> googleRoute({String maneuver = 'TURN_LEFT'}) => {
  'provider': 'google',
  'travel_mode': 'WALK',
  'routes': [
    {
      'distanceMeters': 222,
      'duration': '160.5s',
      'warnings': ['Use the pedestrian entrance.'],
      'polyline': {
        'geoJsonLinestring': {
          'type': 'LineString',
          'coordinates': [
            [0, 0],
            [0.001, 0],
            [0.001, 0.001],
          ],
        },
      },
      'legs': [
        {
          'steps': [
            {
              'distanceMeters': 111,
              'staticDuration': '80s',
              'startLocation': {
                'latLng': {'latitude': 0, 'longitude': 0},
              },
              'navigationInstruction': {
                'maneuver': 'DEPART',
                'instructions': 'Head east',
              },
            },
            {
              'distanceMeters': 111,
              'staticDuration': '80.5s',
              'startLocation': {
                'latLng': {'latitude': 0, 'longitude': 0.001},
              },
              'navigationInstruction': {
                'maneuver': maneuver,
                'instructions': 'Turn left onto the footpath',
              },
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  test('Google geometry, duration, steps and walking mode survive parsing', () {
    final route = RoutingService.parseGoogleResponse(googleRoute());
    expect(route.points.last, const LatLng(.001, .001));
    expect(route.durationSeconds, 160.5);
    expect(route.steps[1].wayPointStart, 1);
    expect(route.steps[1].direction, RouteManeuver.left);
    expect(route.steps.last.direction, RouteManeuver.arrive);
    expect(route.provider, 'google');
    expect(route.travelMode, 'WALK');
    final guidance = NavigationGuidance(route);
    expect(
      guidance.at(const LatLng(0, .0005)).step!.direction,
      RouteManeuver.left,
    );
    expect(
      guidance.at(const LatLng(.0002, .001)).step!.direction,
      RouteManeuver.arrive,
    );
  });

  test('Google U-turn and roundabout enums are kept independently of text', () {
    for (final entry in {
      'UTURN_RIGHT': RouteManeuver.uTurn,
      'ROUNDABOUT_RIGHT': RouteManeuver.roundabout,
      'TURN_SHARP_RIGHT': RouteManeuver.sharpRight,
    }.entries) {
      expect(
        RoutingService.parseGoogleResponse(
          googleRoute(maneuver: entry.key),
        ).steps[1].direction,
        entry.value,
      );
    }
  });

  test('empty routes fail instead of drawing a fake path', () {
    expect(
      () => RoutingService.parseGoogleResponse({'routes': []}),
      throwsA(isA<RoutingException>()),
    );
    final body = googleRoute();
    (body['routes'] as List).first['polyline'] = {};
    expect(
      () => RoutingService.parseGoogleResponse(body),
      throwsA(isA<RoutingException>()),
    );
  });

  test('walking, driving and bicycle use different Google modes', () {
    expect(TransportMode.walking.googleTravelMode, 'WALK');
    expect(TransportMode.driving.googleTravelMode, 'DRIVE');
    expect(TransportMode.cycling.googleTravelMode, 'BICYCLE');
  });

  test(
    'displayed remaining route starts at live projection and keeps the corner',
    () {
      final route = RoutingService.parseGoogleResponse(googleRoute());
      final guidance = NavigationGuidance(route);
      final rest = guidance.remainingPoints(
        guidance.at(const LatLng(0, .0005)),
      );
      expect(rest.length, 3);
      expect(rest.first.longitude, closeTo(.0005, 1e-8));
      expect(rest[1], const LatLng(0, .001));
      expect(rest.last, route.points.last);
      expect(
        guidance.remainingPoints(guidance.at(const LatLng(.01, .01))),
        route.points,
      );
      expect(
        guidance.remainingPoints(guidance.at(route.points.last)).length,
        1,
      );
    },
  );

  test(
    'nearby on-route walking refreshes after movement even without deviation',
    () {
      final route = RoutingService.parseGoogleResponse(googleRoute());
      final guidance = NavigationGuidance(route);
      final policy = RouteRefreshPolicy();
      final now = DateTime(2026);
      policy.recordAttempt(const LatLng(0, .001), now);
      const position = LatLng(.0002, .001);
      bool check(int seconds, double accuracy) => policy.shouldRefresh(
        position: position,
        destination: route.points.last,
        accuracy: accuracy,
        progress: guidance.at(position),
        now: now.add(Duration(seconds: seconds)),
      );
      expect(check(10, 5), false);
      expect(check(16, 5), true);
      expect(check(16, 80), false);
      policy.recordAttempt(position, now);
      expect(
        check(90, 5),
        false,
      ); // Stationary GPS must not repeatedly bill requests.
    },
  );

  test('off-route refresh is throttled and poor GPS is ignored', () {
    final route = RoutingService.parseGoogleResponse(googleRoute());
    final guidance = NavigationGuidance(route);
    const position = LatLng(.003, 0);
    final policy = RouteRefreshPolicy();
    final now = DateTime(2026);
    policy.recordAttempt(route.points.first, now);
    bool check(int seconds, double accuracy) => policy.shouldRefresh(
      position: position,
      destination: route.points.last,
      accuracy: accuracy,
      progress: guidance.at(position),
      now: now.add(Duration(seconds: seconds)),
    );
    expect(check(5, 5), false);
    expect(check(20, 5), true);
    expect(check(20, double.infinity), false);
  });

  testWidgets(
    'Google attribution and pedestrian warnings appear on camera guidance',
    (tester) async {
      final route = RoutingService.parseGoogleResponse(googleRoute());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TurnGuidanceBanner(
                route: route,
                progress: NavigationGuidance(route).at(route.points.first),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Google Maps'), findsOneWidget);
      expect(
        find.textContaining('Walking directions are in beta'),
        findsOneWidget,
      );
      expect(find.text('Use the pedestrian entrance.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
