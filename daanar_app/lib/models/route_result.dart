import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result returned by the routing service after a successful route calculation.
class RouteResult {
  /// Ordered list of GPS points forming the route polyline.
  final List<LatLng> points;

  /// Total route distance in metres.
  final double distanceMetres;

  /// Estimated travel duration in seconds.
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
  });

  /// Human-readable distance string (e.g. "1.2 km" or "850 m").
  String get distanceLabel {
    if (distanceMetres >= 1000) {
      return '${(distanceMetres / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMetres.toStringAsFixed(0)} m';
  }

  /// Human-readable ETA string (e.g. "12 min" or "1 hr 5 min").
  String get etaLabel {
    final totalMinutes = (durationSeconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
  }
}
