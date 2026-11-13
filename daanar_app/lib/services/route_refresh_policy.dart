import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bearing_service.dart';
import 'navigation_guidance.dart';

/// Refresh even while on the old route, with movement and time limits.
class RouteRefreshPolicy {
  DateTime? _lastAttempt;
  LatLng? _lastOrigin;

  void recordAttempt(LatLng origin, DateTime now) {
    _lastOrigin = origin;
    _lastAttempt = now;
  }

  bool shouldRefresh({
    required LatLng position,
    required LatLng destination,
    required double accuracy,
    required NavigationProgress? progress,
    required DateTime now,
  }) {
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 40) return false;
    final elapsed = _lastAttempt == null
        ? const Duration(days: 1)
        : now.difference(_lastAttempt!);
    if (elapsed < const Duration(seconds: 15)) return false;
    if (progress == null) return true;
    if (progress.remaining <= 12 && !progress.offRoute) return false;
    if (progress.deviation > math.max(25, accuracy)) return true;
    final moved = _lastOrigin == null
        ? double.infinity
        : BearingService.distanceMetres(_lastOrigin!, position);
    final nearDestination =
        BearingService.distanceMetres(position, destination) <= 150;
    return (nearDestination && moved >= 10) ||
        (elapsed >= const Duration(seconds: 60) && moved >= 25);
  }
}
