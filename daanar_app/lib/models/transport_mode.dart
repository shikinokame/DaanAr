import 'package:flutter/material.dart';

/// The mode of transport for route calculation.
enum TransportMode {
  walking,
  driving,
  cycling;

  /// Google Routes travel mode for this mode.
  String get googleTravelMode => switch (this) {
    TransportMode.walking => 'WALK',
    TransportMode.driving => 'DRIVE',
    TransportMode.cycling => 'BICYCLE',
  };

  /// Human-readable label.
  String get label => switch (this) {
    TransportMode.walking => 'Walk',
    TransportMode.driving => 'Drive',
    TransportMode.cycling => 'Bicycle',
  };

  /// Material icon for this mode.
  IconData get icon => switch (this) {
    TransportMode.walking => Icons.directions_walk,
    TransportMode.driving => Icons.directions_car_rounded,
    TransportMode.cycling => Icons.directions_bike,
  };

  /// Approximate average speed in metres/second used for live ETA calculation.
  /// Google returns duration in the initial response; this is for the remaining-distance
  /// update in the live nav panel (distance is straight-line, not along route).
  double get speedMetresPerSec => switch (this) {
    TransportMode.walking => 1.4, // ~5 km/h
    TransportMode.driving => 8.3, // ~30 km/h urban average
    TransportMode.cycling => 4.2, // ~15 km/h
  };
}
