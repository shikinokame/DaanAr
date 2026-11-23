import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';

/// Radius in metres a physical visit is triggered when the user enters this 100m zone.
const double kGeofenceRadiusMetres =
    AppConstants.physicalVisitRadiusMetres; // 100.0m

/// Minimum seconds between repeated notifications/logs for the same landmark.
const int kCooldownSeconds = 300; // 5 minutes

/// Watches the user's GPS position, logs `PHYSICAL_VISIT` analytics events,
/// and fires arrival notifications when they enter within 100m of any landmark.
class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  StreamSubscription<Position>? _positionSub;
  List<Landmark> _landmarks = [];
  LandmarkService? _landmarkService;

  /// Tracks which landmark IDs have been recently notified/logged (cooldown).
  final Map<int, DateTime> _lastNotified = {};

  /// Start listening using the same catalog displayed by the app.
  void start(LandmarkService landmarkService) {
    if (_positionSub != null) return;
    _landmarkService = landmarkService;
    _positionSub = LocationService.getPositionStream().listen(
      _checkProximity,
      onError: (_) {},
    );
  }

  void updateLandmarks(List<Landmark> landmarks) {
    _landmarks = landmarks;
  }

  /// Stop the geofence listener (call on app suspend if needed).
  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _landmarkService = null;
    _landmarks = [];
    _lastNotified.clear();
  }

  void _checkProximity(Position position) {
    for (final landmark in _landmarks) {
      final distance = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        landmark.lat,
        landmark.lng,
      );

      if (distance <= kGeofenceRadiusMetres) {
        _triggerArrival(landmark, position);
      }
    }
  }

  void _triggerArrival(Landmark landmark, Position position) {
    final now = DateTime.now();
    final lastTime = _lastNotified[landmark.id];

    // Enforce cooldown to avoid spamming
    if (lastTime != null &&
        now.difference(lastTime).inSeconds < kCooldownSeconds) {
      return;
    }

    _lastNotified[landmark.id] = now;

    // Log verified on-site PHYSICAL_VISIT to backend analytics
    _landmarkService?.logAnalyticsEvent(
      landmarkId: landmark.id,
      actionType: 'PHYSICAL_VISIT',
      verificationMethod: 'GPS_GEOFENCE',
      userLat: position.latitude,
      userLng: position.longitude,
    );

    unawaited(
      NotificationService.instance
          .showArrivalNotification(
            id: landmark.id,
            landmarkName: landmark.name,
            municipality: landmark.municipality?.name ?? 'Pangasinan',
          )
          .catchError((Object _) {}),
    );
  }
}

/// Riverpod provider so the service can be accessed app-wide.
final geofenceServiceProvider = Provider<GeofenceService>(
  (_) => GeofenceService.instance,
);
