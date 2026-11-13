import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/api_client.dart';
import '../models/route_result.dart';
import '../models/transport_mode.dart';

/// Google Routes via the authenticated DaanAR backend. Keys stay on the server.
class RoutingService {
  static final _dio = ApiClient().dio;

  static Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    TransportMode mode = TransportMode.walking,
  }) async {
    try {
      final response = await _dio.post(
        '/routes/compute',
        data: {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
          'travel_mode': mode.googleTravelMode,
        },
        options: Options(receiveTimeout: const Duration(seconds: 22)),
      );
      return parseGoogleResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const RoutingException(
          'Sign in again while online to use Google directions.',
        );
      }
      if (e.response?.statusCode == 429) {
        throw const RoutingException(
          'Directions request limit reached. Please try again later.',
        );
      }
      final body = e.response?.data;
      throw RoutingException(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Could not update directions. Check your connection and try again.',
      );
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException(
        'The directions response was incomplete. Please try again.',
      );
    }
  }

  static RouteResult parseGoogleResponse(Map<String, dynamic> json) {
    try {
      return _parseGoogleResponse(json);
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException('Google returned an incomplete route.');
    }
  }

  static RouteResult _parseGoogleResponse(Map<String, dynamic> json) {
    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) throw const RoutingException('No Google route found.');
    final route = routes.first as Map<String, dynamic>;
    final geometry =
        (route['polyline'] as Map<String, dynamic>?)?['geoJsonLinestring']
            as Map<String, dynamic>?;
    final rawPoints = geometry?['coordinates'] as List<dynamic>? ?? [];
    final points = rawPoints
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    if (points.length < 2 ||
        points.any((p) => !p.latitude.isFinite || !p.longitude.isFinite)) {
      throw const RoutingException('Google returned an incomplete route.');
    }
    final steps = <RouteStep>[];
    var cursor = 0;
    for (final leg in (route['legs'] as List<dynamic>? ?? [])) {
      for (final step in (leg['steps'] as List<dynamic>? ?? [])) {
        final instruction =
            step['navigationInstruction'] as Map<String, dynamic>? ?? {};
        final start =
            (step['startLocation'] as Map<String, dynamic>?)?['latLng']
                as Map<String, dynamic>?;
        int? waypoint;
        if (start != null) {
          var best = double.infinity;
          for (var i = cursor; i < points.length; i++) {
            final dx =
                points[i].longitude - (start['longitude'] as num).toDouble();
            final dy =
                points[i].latitude - (start['latitude'] as num).toDouble();
            final squared = dx * dx + dy * dy;
            if (squared < best) {
              best = squared;
              waypoint = i;
            }
            if (squared < 1e-14) break;
          }
          if (waypoint != null) cursor = waypoint;
        }
        steps.add(
          RouteStep(
            instruction:
                (instruction['instructions'] as String?)?.trim() ??
                'Continue along the route',
            distanceMetres: (step['distanceMeters'] as num? ?? 0).toDouble(),
            durationSeconds: _seconds(step['staticDuration']),
            wayPointStart: waypoint,
            maneuver: switch (instruction['maneuver']) {
              'DEPART' => RouteManeuver.depart,
              'TURN_LEFT' || 'RAMP_LEFT' || 'FORK_LEFT' => RouteManeuver.left,
              'TURN_RIGHT' ||
              'RAMP_RIGHT' ||
              'FORK_RIGHT' => RouteManeuver.right,
              'TURN_SLIGHT_LEFT' => RouteManeuver.slightLeft,
              'TURN_SLIGHT_RIGHT' => RouteManeuver.slightRight,
              'TURN_SHARP_LEFT' => RouteManeuver.sharpLeft,
              'TURN_SHARP_RIGHT' => RouteManeuver.sharpRight,
              'UTURN_LEFT' || 'UTURN_RIGHT' => RouteManeuver.uTurn,
              'ROUNDABOUT_LEFT' ||
              'ROUNDABOUT_RIGHT' => RouteManeuver.roundabout,
              _ => RouteManeuver.straight,
            },
          ),
        );
      }
    }
    // Google's final travel step is not an arrival maneuver.
    steps.add(
      RouteStep(
        instruction: 'Arrive at your destination',
        distanceMetres: 0,
        durationSeconds: 0,
        wayPointStart: points.length - 1,
        maneuver: RouteManeuver.arrive,
      ),
    );
    return RouteResult(
      points: points,
      distanceMetres: (route['distanceMeters'] as num? ?? 0).toDouble(),
      durationSeconds: _seconds(route['duration']),
      steps: steps,
      provider: 'google',
      travelMode: json['travel_mode'] as String? ?? 'WALK',
      warnings: (route['warnings'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }

  static double _seconds(dynamic value) => value is String
      ? double.tryParse(value.replaceFirst(RegExp(r's$'), '')) ?? 0
      : 0;
}

class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);
  @override
  String toString() => message;
}
