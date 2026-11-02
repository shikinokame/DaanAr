import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

// State

/// All possible states the location system can be in.
sealed class LocationState {}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationReady extends LocationState {
  final Position position;
  LocationReady(this.position);
}

class LocationError extends LocationState {
  final String message;
  final LocationExceptionType type;
  LocationError(this.message, this.type);
}

// Notifier

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => LocationInitial();

  /// Requests permission and fetches current GPS position.
  Future<void> requestLocation() async {
    state = LocationLoading();
    try {
      final position = await LocationService.getCurrentPosition();
      state = LocationReady(position);
    } on LocationException catch (e) {
      state = LocationError(e.message, e.type);
    } catch (e) {
      state = LocationError(
        'Could not get location: $e',
        LocationExceptionType.unknown,
      );
    }
  }

  /// Updates position from a stream tick (called by map screen during navigation).
  void updatePosition(Position position) {
    state = LocationReady(position);
  }
}

// Provider

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);
