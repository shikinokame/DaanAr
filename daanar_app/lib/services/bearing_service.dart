import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pure spatial & compass calculations for trail navigation and AR directional guidance.
class BearingService {
  BearingService._();

  /// Straight-line distance in metres between [from] and [to].
  static double distanceMetres(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// True-north bearing in degrees `[0, 360)` from [from] to [to].
  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lat2 = _degToRad(to.latitude);
    final dLon = _degToRad(to.longitude - from.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final brng = _radToDeg(math.atan2(y, x));
    return (brng + 360.0) % 360.0;
  }

  /// Signed relative angle `[-180, +180]` between [deviceHeading] and [targetBearing].
  /// `0` means pointing straight at the landmark; `+90` means target is 90° to the right.
  static double relativeAngle({
    required double targetBearing,
    required double deviceHeading,
  }) {
    var diff = (targetBearing - deviceHeading) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  /// 8-point cardinal direction label (`N`, `NE`, `E`, `SE`, `S`, `SW`, `W`, `NW`).
  static String cardinalLabel(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((bearing + 22.5) % 360.0) ~/ 45;
    return dirs[idx % 8];
  }

  /// Full cardinal word (`North`, `Northeast`, etc.).
  static String cardinalWord(double bearing) {
    const words = [
      'North',
      'Northeast',
      'East',
      'Southeast',
      'South',
      'Southwest',
      'West',
      'Northwest',
    ];
    final idx = ((bearing + 22.5) % 360.0) ~/ 45;
    return words[idx % 8];
  }

  /// Human-readable directional prompt from signed relative angle.
  static String directionalPrompt(double relAngle) {
    final absAngle = relAngle.abs();
    if (absAngle <= 18) return 'Straight ahead';
    if (absAngle <= 50) {
      return relAngle > 0 ? 'Bear slightly right' : 'Bear slightly left';
    }
    if (absAngle <= 120) {
      return relAngle > 0 ? 'Turn right' : 'Turn left';
    }
    return 'Turn around';
  }

  /// Formats distance in metres into `85 m` or `1.4 km`.
  static String formatDistance(double metres) {
    if (metres >= 1000) {
      return '${(metres / 1000).toStringAsFixed(1)} km';
    }
    return '${metres.round()} m';
  }

  /// Estimates travel time label from distance in metres.
  static String formatEta(double metres, {bool walking = true}) {
    final speedMps = walking ? 1.35 : 8.5;
    final mins = math.max(1, (metres / speedMps / 60).round());
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem min';
  }

  static double _degToRad(double d) => d * math.pi / 180.0;
  static double _radToDeg(double r) => r * 180.0 / math.pi;
}

