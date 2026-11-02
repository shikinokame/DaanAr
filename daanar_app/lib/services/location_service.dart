import 'package:geolocator/geolocator.dart';

/// Handles GPS permission and position reads for DaanAR navigation.
class LocationService {
  /// Checks/requests permission and returns the current GPS position.
  ///
  /// Throws a [LocationException] with a user-readable message on any failure
  /// so callers can show a meaningful error instead of a raw exception.
  static Future<Position> getCurrentPosition() async {
    // 1. Check if location services are enabled on the device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. Please enable GPS in your device settings.',
        LocationExceptionType.serviceDisabled,
      );
    }

    // 2. Check / request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
          'Location permission was denied. Please allow location access to use navigation.',
          LocationExceptionType.permissionDenied,
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission is permanently denied. Please enable it in App Settings.',
        LocationExceptionType.permissionPermanentlyDenied,
      );
    }

    // 3. Fetch position (high accuracy, 15s timeout)
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Returns a continuous stream of GPS positions for live navigation.
  /// Only starts after permission is confirmed call [getCurrentPosition] first.
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // emit only when moved ≥ 5 metres
      ),
    );
  }

  /// Calculates straight-line distance in metres between two lat/lng points.
  static double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}

// Exception types

enum LocationExceptionType {
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  unknown,
}

class LocationException implements Exception {
  final String message;
  final LocationExceptionType type;
  const LocationException(this.message, this.type);

  @override
  String toString() => message;
}
