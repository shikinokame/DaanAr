import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RouteManeuver {
  straight,
  left,
  right,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  uTurn,
  roundabout,
  arrive,
  depart;

  static RouteManeuver fromInstruction(String text) {
    // Street names such as Wright Street or Left Bank Road are not maneuvers.
    final value = text
        .toLowerCase()
        .split(RegExp(r'\b(?:onto|along|towards?)\b'))
        .first
        .trim();
    if (value.startsWith('arriv') ||
        value.startsWith('reach your destination')) {
      return arrive;
    }
    if (value.contains('roundabout') || value.contains('rotary')) {
      return roundabout;
    }
    if (value.contains('u-turn') || value.contains('uturn')) return uTurn;
    if (value.contains('sharp left')) return sharpLeft;
    if (value.contains('sharp right')) return sharpRight;
    if (value.contains('slight left') || value.contains('slightly left')) {
      return slightLeft;
    }
    if (value.contains('slight right') || value.contains('slightly right')) {
      return slightRight;
    }
    if (value.contains('left')) return left;
    if (value.contains('right')) return right;
    if (RegExp(r'^(head|start)(\s|$)').hasMatch(value)) return depart;
    return straight;
  }
}

/// A single turn-by-turn maneuver along a calculated street route.
class RouteStep {
  final String instruction;
  final double distanceMetres;
  final double durationSeconds;
  final String name;
  final int? wayPointStart;
  final int? wayPointEnd;
  final RouteManeuver? maneuver;

  const RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.durationSeconds,
    this.name = '',
    this.wayPointStart,
    this.wayPointEnd,
    this.maneuver,
  });

  RouteManeuver get direction =>
      maneuver ?? RouteManeuver.fromInstruction(instruction);
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
  final String? provider;
  final String? travelMode;
  final List<String> warnings;

  const RouteResult({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
    this.steps = const [],
    this.provider,
    this.travelMode,
    this.warnings = const [],
  });

  String? get advisory => switch (travelMode) {
    'WALK' =>
      'Walking directions are in beta and may omit sidewalks or pedestrian paths.',
    'BICYCLE' => 'Bicycle directions are in beta and may omit cycling paths.',
    _ => null,
  };

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
