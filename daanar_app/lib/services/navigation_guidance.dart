import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_result.dart';
import 'bearing_service.dart';

/// Projects a GPS fix onto road segments, rather than the nearest map vertex.
/// Distances to maneuvers and the destination are measured along that road.
class NavigationGuidance {
  final RouteResult route;
  late final List<double> _distances;
  late final List<double> _stepOffsets;

  NavigationGuidance(this.route) {
    _distances = [0];
    for (var i = 1; i < route.points.length; i++) {
      _distances.add(
        _distances.last +
            BearingService.distanceMetres(route.points[i - 1], route.points[i]),
      );
    }
    final stepsLength = route.steps.fold<double>(
      0,
      (n, s) => n + s.distanceMetres,
    );
    var consumed = 0.0;
    _stepOffsets = route.steps.map((step) {
      final index = step.wayPointStart;
      final offset = index != null && index >= 0 && index < _distances.length
          ? _distances[index]
          : (stepsLength > 0 ? consumed / stepsLength * length : 0.0);
      consumed += step.distanceMetres;
      return offset;
    }).toList();
  }

  double get length => _distances.last;

  NavigationProgress at(LatLng position, {double? previousAlong}) {
    if (route.points.length < 2 || length == 0) {
      return const NavigationProgress(
        along: 0,
        remaining: 0,
        secondsRemaining: 0,
        deviation: double.infinity,
        distanceToTurn: 0,
      );
    }
    var along = 0.0;
    var deviation = double.infinity;
    var bestScore = double.infinity;
    final cosLat = math.cos(position.latitude * math.pi / 180);
    const metres = 111195.0;
    for (var i = 0; i < route.points.length - 1; i++) {
      final a = route.points[i];
      final b = route.points[i + 1];
      final ax = (a.longitude - position.longitude) * metres * cosLat;
      final ay = (a.latitude - position.latitude) * metres;
      final dx = (b.longitude - a.longitude) * metres * cosLat;
      final dy = (b.latitude - a.latitude) * metres;
      final squared = dx * dx + dy * dy;
      final t = squared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / squared).clamp(0.0, 1.0);
      final distance = math.sqrt(
        math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2),
      );
      final projected = _distances[i] + t * (_distances[i + 1] - _distances[i]);
      // Prefer continuity at intersections, while still allowing real backtracking.
      final continuity = previousAlong == null
          ? 0.0
          : math.min(8.0, (projected - previousAlong).abs() * 0.02);
      final score = distance + continuity;
      if (score < bestScore) {
        bestScore = score;
        deviation = distance;
        along = projected;
      }
    }
    final remaining = math.max(0.0, length - along);
    RouteStep? step;
    RouteStep? then;
    var distanceToTurn = remaining;
    for (var i = 0; i < route.steps.length; i++) {
      final candidate = route.steps[i];
      if (candidate.direction == RouteManeuver.depart) continue;
      // Maneuvers occur at each step START. Keep the turn through the junction
      // until the fix is 8 m beyond it, so GPS jitter does not skip it early.
      if (_stepOffsets[i] + 8 >= along) {
        step = candidate;
        distanceToTurn = math.max(0.0, _stepOffsets[i] - along);
        if (i + 1 < route.steps.length) then = route.steps[i + 1];
        break;
      }
    }
    if (remaining <= 12 && deviation <= 25) {
      step = const RouteStep(
        instruction: 'Arrive at your destination',
        distanceMetres: 0,
        durationSeconds: 0,
        maneuver: RouteManeuver.arrive,
      );
      distanceToTurn = remaining;
      then = null;
    }
    return NavigationProgress(
      along: along,
      remaining: remaining,
      secondsRemaining: route.durationSeconds * remaining / length,
      deviation: deviation,
      step: step,
      then: then,
      distanceToTurn: distanceToTurn,
      lookAhead: pointAt(math.min(length, along + 18)),
    );
  }

  LatLng pointAt(double distance) {
    for (var i = 1; i < _distances.length; i++) {
      if (_distances[i] >= distance && _distances[i] > _distances[i - 1]) {
        final t =
            ((distance - _distances[i - 1]) /
                    (_distances[i] - _distances[i - 1]))
                .clamp(0.0, 1.0);
        final a = route.points[i - 1];
        final b = route.points[i];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
    }
    return route.points.last;
  }

  /// Start the displayed line at the projected position, retaining road bends.
  /// Keep the full route when GPS is inaccurate/off route; do not draw a shortcut.
  List<LatLng> remainingPoints(NavigationProgress? progress) {
    if (progress == null ||
        progress.offRoute ||
        route.points.length < 2 ||
        length == 0) {
      return route.points;
    }
    final along = progress.along.clamp(0.0, length);
    return [
      pointAt(along),
      for (var i = 0; i < route.points.length; i++)
        if (_distances[i] > along + 0.01) route.points[i],
    ];
  }
}

class NavigationProgress {
  final double along, remaining, secondsRemaining, deviation, distanceToTurn;
  final RouteStep? step, then;
  final LatLng? lookAhead;
  const NavigationProgress({
    required this.along,
    required this.remaining,
    required this.secondsRemaining,
    required this.deviation,
    required this.distanceToTurn,
    this.step,
    this.then,
    this.lookAhead,
  });

  bool get offRoute => deviation > 35;
  String get etaLabel {
    if (remaining <= 12 && !offRoute) return 'Arrived';
    final minutes = math.max(1, (secondsRemaining / 60).ceil());
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} hr ${minutes % 60} min';
  }
}
