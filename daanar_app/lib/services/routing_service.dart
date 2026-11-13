import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../models/route_result.dart';
import '../models/transport_mode.dart';

/// Calls OpenRouteService (with OSRM fallback) to calculate a road-snapped
/// walking/cycling/driving route between two points, including full street
/// geometry and turn-by-turn instructions.
class RoutingService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.orsBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Authorization': AppConstants.orsApiKey,
        'Accept': 'application/json, application/geo+json',
      },
    ),
  );

  static final _osrmDio = Dio(
    BaseOptions(
      baseUrl: 'https://router.project-osrm.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Calculates a road-snapped route from [origin] to [destination] using [mode].
  ///
  /// Throws a [RoutingException] with a user-readable message if both ORS and
  /// the backup OSRM router fail.
  static Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    TransportMode mode = TransportMode.walking,
  }) async {
    // 1. Primary: OpenRouteService (/v2/directions/foot-walking, etc.)
    if (AppConstants.orsApiKey != 'YOUR_ORS_API_KEY') {
      try {
        final response = await _dio.get(
          '/v2/directions/${mode.orsProfile}',
          queryParameters: {
            // ORS uses [longitude, latitude] order
            'start': '${origin.longitude},${origin.latitude}',
            'end': '${destination.longitude},${destination.latitude}',
          },
        );

        final parsed = parseOrsResponse(response.data as Map<String, dynamic>);
        if (parsed.points.length >= 2) {
          return parsed;
        }
      } catch (_) {
        // Fall through to OSRM street router backup
      }
    }

    // 2. Backup: OSRM public router with full GeoJSON street geometry & steps
    try {
      final osrmProfile = switch (mode) {
        TransportMode.walking => 'foot',
        TransportMode.cycling => 'bike',
        TransportMode.driving => 'car',
      };
      final coords =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final response = await _osrmDio.get(
        '/route/v1/$osrmProfile/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );
      return parseOsrmResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw RoutingException(
        'Could not calculate road route: ${e.message ?? 'Network error'}',
      );
    } catch (e) {
      throw RoutingException('Routing error: $e');
    }
  }

  static RouteResult parseOrsResponse(Map<String, dynamic> json) {
    final features = json['features'] as List<dynamic>? ?? [];
    if (features.isEmpty) throw const RoutingException('No route found.');

    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;

    // Extract full road polyline ORS returns [lng, lat] pairs
    final rawCoords = (geometry['coordinates'] as List<dynamic>)
        .cast<List<dynamic>>();
    final points = rawCoords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    // Extract distance + duration from summary (or first segment)
    final summary = properties['summary'] as Map<String, dynamic>? ?? {};
    final segments = properties['segments'] as List<dynamic>? ?? [];
    final firstSeg = segments.isNotEmpty
        ? segments.first as Map<String, dynamic>
        : <String, dynamic>{};

    final distance = ((summary['distance'] ?? firstSeg['distance'] ?? 0) as num)
        .toDouble();
    final duration = ((summary['duration'] ?? firstSeg['duration'] ?? 0) as num)
        .toDouble();

    // Extract turn-by-turn street instructions from segments[0].steps
    final steps = <RouteStep>[];
    for (final seg in segments.whereType<Map<String, dynamic>>()) {
      final rawSteps = seg['steps'] as List<dynamic>? ?? [];
      for (final s in rawSteps.whereType<Map<String, dynamic>>()) {
        final instruction = (s['instruction'] as String?)?.trim() ?? '';
        if (instruction.isEmpty) continue;
        final wp = s['way_points'] as List<dynamic>?;
        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMetres: ((s['distance'] ?? 0) as num).toDouble(),
            durationSeconds: ((s['duration'] ?? 0) as num).toDouble(),
            name: (s['name'] as String?) ?? '',
            maneuver: switch ((s['type'] as num?)?.toInt()) {
              0 => RouteManeuver.left,
              1 => RouteManeuver.right,
              2 => RouteManeuver.sharpLeft,
              3 => RouteManeuver.sharpRight,
              4 || 12 => RouteManeuver.slightLeft,
              5 || 13 => RouteManeuver.slightRight,
              6 => RouteManeuver.straight,
              7 || 8 => RouteManeuver.roundabout,
              9 => RouteManeuver.uTurn,
              10 => RouteManeuver.arrive,
              11 => RouteManeuver.depart,
              _ => RouteManeuver.fromInstruction(instruction),
            },
            wayPointStart: (wp != null && wp.isNotEmpty)
                ? (wp[0] as num).toInt()
                : null,
            wayPointEnd: (wp != null && wp.length > 1)
                ? (wp[1] as num).toInt()
                : null,
          ),
        );
      }
    }

    return RouteResult(
      points: points,
      distanceMetres: distance,
      durationSeconds: duration,
      steps: steps,
    );
  }

  static RouteResult parseOsrmResponse(Map<String, dynamic> json) {
    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) throw const RoutingException('No route found.');

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final rawCoords = (geometry['coordinates'] as List<dynamic>)
        .cast<List<dynamic>>();
    final points = rawCoords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final distance = ((route['distance'] ?? 0) as num).toDouble();
    final duration = ((route['duration'] ?? 0) as num).toDouble();

    final steps = <RouteStep>[];
    final legs = route['legs'] as List<dynamic>? ?? [];
    var cursor = 0;
    for (final leg in legs.whereType<Map<String, dynamic>>()) {
      final rawSteps = leg['steps'] as List<dynamic>? ?? [];
      for (final s in rawSteps.whereType<Map<String, dynamic>>()) {
        final name = (s['name'] as String?)?.trim() ?? '';
        final maneuver = s['maneuver'] as Map<String, dynamic>? ?? {};
        final type = (maneuver['type'] as String?) ?? 'continue';
        final modifier = (maneuver['modifier'] as String?) ?? '';
        final location = maneuver['location'] as List<dynamic>?;
        int? waypoint;
        if (location != null && location.length >= 2) {
          var best = double.infinity;
          for (var i = cursor; i < points.length; i++) {
            final dx = points[i].longitude - (location[0] as num).toDouble();
            final dy = points[i].latitude - (location[1] as num).toDouble();
            final distance = dx * dx + dy * dy;
            if (distance < best) {
              best = distance;
              waypoint = i;
            }
            if (distance < 1e-14) break;
          }
          if (waypoint != null) cursor = waypoint;
        }
        final direction = type == 'depart'
            ? RouteManeuver.depart
            : type == 'arrive'
            ? RouteManeuver.arrive
            : type.contains('roundabout') || type.contains('rotary')
            ? RouteManeuver.roundabout
            : RouteManeuver.fromInstruction(modifier);

        String instruction;
        if (type == 'depart') {
          instruction = name.isNotEmpty
              ? 'Head along $name'
              : 'Start along the road';
        } else if (type == 'arrive') {
          instruction = 'Arrive at your destination';
        } else if (direction == RouteManeuver.roundabout) {
          final exit = maneuver['exit'];
          instruction = exit == null
              ? 'Continue around the roundabout'
              : 'At the roundabout, take exit $exit';
        } else if (modifier == 'uturn') {
          instruction = 'Make a U-turn${name.isNotEmpty ? ' onto $name' : ''}';
        } else if (modifier.isNotEmpty && modifier != 'straight') {
          instruction = 'Turn $modifier${name.isNotEmpty ? ' onto $name' : ''}';
        } else if (name.isNotEmpty) {
          instruction = 'Continue onto $name';
        } else {
          instruction = 'Continue along the road';
        }

        steps.add(
          RouteStep(
            instruction: instruction,
            distanceMetres: ((s['distance'] ?? 0) as num).toDouble(),
            durationSeconds: ((s['duration'] ?? 0) as num).toDouble(),
            name: name,
            maneuver: direction,
            wayPointStart: waypoint,
          ),
        );
      }
    }

    return RouteResult(
      points: points,
      distanceMetres: distance,
      durationSeconds: duration,
      steps: steps,
    );
  }
}

// Exception

class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => message;
}
