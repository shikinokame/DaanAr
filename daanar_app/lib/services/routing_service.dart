import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../models/route_result.dart';

/// Calls OpenRouteService to calculate a walking route between two points.
///
/// ORS free tier: 2,000 requests/day — sufficient for development and demo.
/// Sign up at: https://openrouteservice.org/dev/#/signup
class RoutingService {
  static final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.orsBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      // New ORS JWT tokens go in the Authorization header (not ?api_key=)
      'Authorization': AppConstants.orsApiKey,
      'Accept': 'application/json, application/geo+json',
    },
  ));

  /// Calculates a walking route from [origin] to [destination].
  ///
  /// Throws a [RoutingException] with a user-readable message on failure.
  static Future<RouteResult> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (AppConstants.orsApiKey == 'YOUR_ORS_API_KEY') {
      throw RoutingException(
        'OpenRouteService API key not set.\n'
        'Sign up at openrouteservice.org and paste your key in constants.dart',
      );
    }

    try {
      final response = await _dio.get(
        '/v2/directions/foot-walking',
        queryParameters: {
          // ORS uses [longitude, latitude] order — opposite of Google Maps
          'start': '${origin.longitude},${origin.latitude}',
          'end': '${destination.longitude},${destination.latitude}',
        },
      );

      return _parseResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw RoutingException('Invalid ORS API key. Check constants.dart.');
      }
      if (e.response?.statusCode == 429) {
        throw RoutingException('ORS rate limit reached. Try again in a moment.');
      }
      throw RoutingException(
        'Could not calculate route: ${e.message ?? 'Network error'}',
      );
    } catch (e) {
      throw RoutingException('Routing error: $e');
    }
  }

  static RouteResult _parseResponse(Map<String, dynamic> json) {
    final features = json['features'] as List<dynamic>;
    if (features.isEmpty) throw RoutingException('No route found.');

    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;

    // Extract route polyline — ORS returns [lng, lat] pairs
    final rawCoords = (geometry['coordinates'] as List<dynamic>)
        .cast<List<dynamic>>();
    final points = rawCoords
        .map((c) => LatLng(c[1] as double, c[0] as double))
        .toList();

    // Extract distance + duration from summary
    final summary = properties['summary'] as Map<String, dynamic>;
    final distance = (summary['distance'] as num).toDouble();
    final duration = (summary['duration'] as num).toDouble();

    return RouteResult(
      points: points,
      distanceMetres: distance,
      durationSeconds: duration,
    );
  }
}

// ── Exception ─────────────────────────────────────────────────────────────────

class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => message;
}
