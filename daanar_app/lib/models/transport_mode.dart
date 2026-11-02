import 'package:flutter/material.dart';

/// The mode of transport for route calculation.
enum TransportMode {
  walking,
  driving,
  cycling;

  /// ORS route profile name for this mode.
  String get orsProfile => switch (this) {
        TransportMode.walking => 'foot-walking',
        TransportMode.driving => 'driving-car',
        TransportMode.cycling => 'cycling-regular',
      };

  /// Human-readable label.
  String get label => switch (this) {
        TransportMode.walking => 'Walk',
        TransportMode.driving => 'Drive',
        TransportMode.cycling => 'Two-wheeler',
      };

  /// Material icon for this mode.
  IconData get icon => switch (this) {
        TransportMode.walking => Icons.directions_walk,
        TransportMode.driving => Icons.directions_car_rounded,
        TransportMode.cycling => Icons.two_wheeler,
      };

  /// Approximate average speed in metres/second used for live ETA calculation.
  /// ORS returns duration in the initial response; this is for the remaining-distance
  /// update in the live nav panel (distance is straight-line, not along route).
  double get speedMetresPerSec => switch (this) {
        TransportMode.walking => 1.4,  // ~5 km/h
        TransportMode.driving => 8.3,  // ~30 km/h urban average
        TransportMode.cycling => 4.2,  // ~15 km/h
      };
}
