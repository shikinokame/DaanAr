import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/bearing_service.dart';

/// A single turn-by-turn maneuver along a calculated street route.
class RouteStep {
  final String instruction;
  final double distanceMetres;
  final double durationSeconds;
  final String name;
  final int? wayPointStart;
  final int? wayPointEnd;

  const RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.durationSeconds,
    this.name = '',
    this.wayPointStart,
    this.wayPointEnd,
  });
}

/// Result returned by the routing service after a successful route calculation.
class RouteResult {
  /// Ordered list of road-snapped GPS points forming the route polyline.
  final List<LatLng> points;

  /// Total route distance in metres along walkable roads.
  final double distanceMetres;

  /// Estimated travel duration in seconds.
  final double durationSeconds;

  /// Turn-by-turn street instructions along the route.
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
    this.steps = const [],
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

  /// Returns the active turn-by-turn instruction for [userPos] based on the
  /// closest vertex along [points].
  String? activeInstructionFor(LatLng? userPos) {
    if (steps.isEmpty) return null;
    if (userPos == null || points.isEmpty) {
      return steps.first.instruction;
    }

    int closestVertex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final d = BearingService.distanceMetres(userPos, points[i]);
      if (d < minDistance) {
        minDistance = d;
        closestVertex = i;
      }
    }

    for (final step in steps) {
      final start = step.wayPointStart;
      final end = step.wayPointEnd;
      if (start != null && end != null) {
        if (closestVertex >= start && closestVertex <= end) {
          // If the user is near the end of the current step and there's a next
          // maneuver (turn), preview that upcoming turn when within 25m of end.
          return step.instruction;
        }
      }
    }

    return steps.first.instruction;
  }
}
