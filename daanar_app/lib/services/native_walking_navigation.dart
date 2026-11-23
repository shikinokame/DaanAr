import 'package:flutter/services.dart';
import '../models/route_result.dart';

/// Codec for the native screen. Route coordinates remain in memory only.
class NativeWalkingNavigation {
  static const channel = MethodChannel('ph.daanar/navigation');

  static Map<String, Object?> encodeRoute(RouteResult route) {
    if (route.travelMode != 'WALK' ||
        route.points.length < 2 ||
        route.points.length > 30000) {
      throw const FormatException('A valid walking route is required for AR.');
    }
    return {
      'travelMode': 'WALK',
      'points': route.points.map((p) => [p.latitude, p.longitude]).toList(),
      'steps': route.steps
          .where((s) => s.wayPointStart != null)
          .map((s) => {'index': s.wayPointStart, 'instruction': s.instruction})
          .toList(),
      'warnings': route.warnings,
    };
  }
}
