import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/route_result.dart';
import '../providers/landmark_providers.dart';
import '../providers/location_provider.dart';
import '../providers/municipality_providers.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../widgets/category_badge.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  String? _selectedMunicipality;
  Landmark? _selectedLandmark;

  // Route state
  RouteResult? _activeRoute;
  Landmark? _routeDestination;
  bool _isCalculatingRoute = false;

  // Stage 3 — live navigation state
  StreamSubscription<dynamic>? _positionSubscription;
  bool _isNavMode = false;
  LatLng? _livePosition;          // updates every ≥5 m moved
  double? _remainingMetres;       // straight-line to destination (live)
  bool _autoCenter = true;        // camera follows user when true

  static const _initialPosition = CameraPosition(
    target: LatLng(16.0430, 120.3333),
    zoom: 11.5,
  );

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location (one-shot) ──────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    await ref.read(locationProvider.notifier).requestLocation();
    final locState = ref.read(locationProvider);
    if (locState is LocationReady && _mapController != null) {
      final pos = LatLng(locState.position.latitude, locState.position.longitude);
      setState(() => _livePosition = pos);
      await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    } else if (locState is LocationError && mounted) {
      _showSnackBar(
        locState.message,
        action: locState.type == LocationExceptionType.permissionPermanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                textColor: AppColors.secondary,
                onPressed: openAppSettings,
              )
            : null,
      );
    }
  }

  // ── Routing ──────────────────────────────────────────────────────────────────

  Future<void> _navigateTo(Landmark destination) async {
    // Ensure GPS fix
    var locState = ref.read(locationProvider);
    if (locState is! LocationReady) {
      await ref.read(locationProvider.notifier).requestLocation();
      locState = ref.read(locationProvider);
    }
    if (locState is! LocationReady) {
      _showSnackBar('Enable location to use navigation.');
      return;
    }

    final originPos = LatLng(
      locState.position.latitude,
      locState.position.longitude,
    );

    setState(() {
      _isCalculatingRoute = true;
      _activeRoute = null;
      _routeDestination = destination;
      _livePosition = originPos;
    });

    try {
      final dest = LatLng(destination.lat, destination.lng);
      final route = await RoutingService.getWalkingRoute(
        origin: originPos,
        destination: dest,
      );

      setState(() {
        _activeRoute = route;
        _isCalculatingRoute = false;
        _remainingMetres = route.distanceMetres;
      });

      await _fitRouteBounds(originPos, dest);
      _startPositionStream(destination);
    } on RoutingException catch (e) {
      setState(() {
        _isCalculatingRoute = false;
        _routeDestination = null;
      });
      _showSnackBar(e.message);
    }
  }

  // ── Stage 3: live position stream ────────────────────────────────────────────

  void _startPositionStream(Landmark destination) {
    _positionSubscription?.cancel();
    setState(() {
      _isNavMode = true;
      _autoCenter = true;
    });

    _positionSubscription = LocationService.getPositionStream().listen((position) {
      if (!mounted) return;
      final newPos = LatLng(position.latitude, position.longitude);

      // Update distance remaining (straight-line to destination)
      final remaining = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        destination.lat,
        destination.lng,
      );

      setState(() {
        _livePosition = newPos;
        _remainingMetres = remaining;
      });

      // Update location provider so blue dot re-renders
      ref.read(locationProvider.notifier).updatePosition(position);

      // Auto-center camera on user
      if (_autoCenter && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(newPos));
      }
    });
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _isNavMode = false;
      _activeRoute = null;
      _routeDestination = null;
      _remainingMetres = null;
      _autoCenter = true;
    });
  }

  Future<void> _fitRouteBounds(LatLng origin, LatLng dest) async {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        origin.latitude < dest.latitude ? origin.latitude : dest.latitude,
        origin.longitude < dest.longitude ? origin.longitude : dest.longitude,
      ),
      northeast: LatLng(
        origin.latitude > dest.latitude ? origin.latitude : dest.latitude,
        origin.longitude > dest.longitude ? origin.longitude : dest.longitude,
      ),
    );
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        action: action,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final landmarksAsync = ref.watch(landmarkListProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);
    final locationState = ref.watch(locationProvider);
    final isLocating = locationState is LocationLoading;

    // Use live stream position, fall back to one-shot provider position
    final LatLng? userPos = _livePosition ??
        (locationState is LocationReady
            ? LatLng(locationState.position.latitude,
                locationState.position.longitude)
            : null);

    return Scaffold(
      appBar: _isNavMode
          ? null // hide AppBar during navigation for more map space
          : AppBar(
              title: const Text('Heritage Map'),
              actions: [
                if (_activeRoute != null)
                  IconButton(
                    icon: const Icon(Icons.directions_off),
                    tooltip: 'Clear route',
                    onPressed: _stopNavigation,
                  )
                else if (_selectedMunicipality != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    tooltip: 'Clear filter',
                    onPressed: () =>
                        setState(() => _selectedMunicipality = null),
                  ),
              ],
            ),
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────────
          landmarksAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (result) {
              final filtered = _selectedMunicipality == null
                  ? result.landmarks
                  : result.landmarks
                      .where((l) =>
                          l.municipality?.name == _selectedMunicipality)
                      .toList();

              final markers = filtered.map((l) {
                final isDest = _routeDestination?.id == l.id;
                return Marker(
                  markerId: MarkerId(l.id.toString()),
                  position: LatLng(l.lat, l.lng),
                  infoWindow: InfoWindow(title: l.name, snippet: l.category),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isDest ? BitmapDescriptor.hueRed : _categoryHue(l.category),
                  ),
                  zIndex: isDest ? 1 : 0,
                  onTap: () => setState(() => _selectedLandmark = l),
                );
              }).toSet();

              // Blue GPS dot (uses live stream position when available)
              final allMarkers = {...markers};
              if (userPos != null) {
                allMarkers.add(Marker(
                  markerId: const MarkerId('user_location'),
                  position: userPos,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: 'You are here'),
                  zIndex: 2,
                ));
              }

              // Route polyline
              final polylines = <Polyline>{};
              if (_activeRoute != null) {
                polylines.add(Polyline(
                  polylineId: const PolylineId('route'),
                  points: _activeRoute!.points,
                  color: AppColors.primary,
                  width: 5,
                  patterns: [],
                ));
              }

              return GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: allMarkers,
                polylines: polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (c) => _mapController = c,
                onTap: (_) => setState(() => _selectedLandmark = null),
                // Disable auto-center when user manually moves the map
                onCameraMove: (_) {
                  if (_isNavMode && _autoCenter) {
                    setState(() => _autoCenter = false);
                  }
                },
              );
            },
          ),

          // ── Municipality filter chips (hidden during nav mode) ─────────────
          if (!_isNavMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: municipalitiesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _1) => const SizedBox.shrink(),
                data: (result) => Container(
                  color: Colors.white.withValues(alpha: 0.93),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _filterChip('All', _selectedMunicipality == null,
                            () => setState(() => _selectedMunicipality = null)),
                        ...result.municipalities.map((m) => _filterChip(
                              m.name,
                              _selectedMunicipality == m.name,
                              () {
                                setState(() => _selectedMunicipality = m.name);
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                      LatLng(m.lat, m.lng), 13),
                                );
                              },
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Route calculating indicator ───────────────────────────────────
          if (_isCalculatingRoute)
            Positioned(
              top: _isNavMode ? 0 : 62,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Calculating route…',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Static route info panel (non-nav mode) ────────────────────────
          if (_activeRoute != null && !_isNavMode)
            Positioned(
              top: 62,
              left: 12,
              right: 12,
              child: _RouteInfoPanel(
                route: _activeRoute!,
                destination: _routeDestination!,
                onClear: _stopNavigation,
              ),
            ),

          // ── LIVE NAV PANEL (Stage 3) ──────────────────────────────────────
          if (_isNavMode && _routeDestination != null)
            _LiveNavPanel(
              destination: _routeDestination!,
              remainingMetres: _remainingMetres,
              initialRoute: _activeRoute,
              autoCenter: _autoCenter,
              onRecenter: () {
                setState(() => _autoCenter = true);
                if (userPos != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(userPos, 17),
                  );
                }
              },
              onStop: _stopNavigation,
            ),

          // ── FABs (hidden during nav — panel has recenter button) ──────────
          if (!_isNavMode)
            Positioned(
              bottom: _selectedLandmark != null ? 140 : 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'my_location',
                onPressed: isLocating ? null : _goToMyLocation,
                backgroundColor: Colors.white,
                child: isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),

          // ── Landmark preview sheet ─────────────────────────────────────────
          if (_selectedLandmark != null && !_isNavMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LandmarkPreviewSheet(
                landmark: _selectedLandmark!,
                isNavigating: _routeDestination?.id == _selectedLandmark!.id,
                isCalculating: _isCalculatingRoute,
                onClose: () => setState(() => _selectedLandmark = null),
                onViewDetails: () =>
                    context.push('/landmarks/${_selectedLandmark!.id}'),
                onNavigate: () => _navigateTo(_selectedLandmark!),
                onClearRoute: _stopNavigation,
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.charcoal,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: AppColors.cardBg,
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  double _categoryHue(String cat) => switch (cat) {
        'church' => BitmapDescriptor.hueOrange,
        'park' => BitmapDescriptor.hueGreen,
        'historical' => BitmapDescriptor.hueViolet,
        'natural' => BitmapDescriptor.hueCyan,
        'cultural' => BitmapDescriptor.hueMagenta,
        _ => BitmapDescriptor.hueRed,
      };
}

// ── Live Navigation Panel (Stage 3) ──────────────────────────────────────────

class _LiveNavPanel extends StatelessWidget {
  final Landmark destination;
  final double? remainingMetres;
  final RouteResult? initialRoute;
  final bool autoCenter;
  final VoidCallback onRecenter;
  final VoidCallback onStop;

  const _LiveNavPanel({
    required this.destination,
    required this.remainingMetres,
    required this.initialRoute,
    required this.autoCenter,
    required this.onRecenter,
    required this.onStop,
  });

  String get _distanceLabel {
    final m = remainingMetres ?? initialRoute?.distanceMetres;
    if (m == null) return '—';
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  String get _etaLabel {
    final m = remainingMetres ?? initialRoute?.distanceMetres;
    if (m == null) return '—';
    // Average walking speed: ~1.4 m/s = 84 m/min
    final minutes = (m / 84).ceil();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final min = minutes % 60;
    return min == 0 ? '$h hr' : '$h hr $min min';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          // ── Top nav bar ────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          destination.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_distanceLabel  ·  $_etaLabel walk',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom controls ────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Recenter button
                if (!autoCenter)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: FloatingActionButton.small(
                      heroTag: 'recenter',
                      onPressed: onRecenter,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),

                // Stop Navigation button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: const Text(
                      'Stop Navigation',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static Route Info Panel ───────────────────────────────────────────────────

class _RouteInfoPanel extends StatelessWidget {
  final RouteResult route;
  final Landmark destination;
  final VoidCallback onClear;

  const _RouteInfoPanel({
    required this.route,
    required this.destination,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.distanceLabel}  ·  ${route.etaLabel} walk',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Landmark Preview Sheet ────────────────────────────────────────────────────

class _LandmarkPreviewSheet extends StatelessWidget {
  final Landmark landmark;
  final bool isNavigating;
  final bool isCalculating;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;
  final VoidCallback onNavigate;
  final VoidCallback onClearRoute;

  const _LandmarkPreviewSheet({
    required this.landmark,
    required this.isNavigating,
    required this.isCalculating,
    required this.onClose,
    required this.onViewDetails,
    required this.onNavigate,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: (AppColors.categoryColors[landmark.category] ??
                            AppColors.primary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    switch (landmark.category) {
                      'church' => Icons.church,
                      'park' => Icons.park,
                      'historical' => Icons.account_balance,
                      'natural' => Icons.landscape,
                      'cultural' => Icons.museum,
                      _ => Icons.place,
                    },
                    color: AppColors.categoryColors[landmark.category] ??
                        AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landmark.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.charcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          CategoryBadge(category: landmark.category, small: true),
                          const SizedBox(width: 6),
                          Text(
                            landmark.municipality?.name ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textMuted),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCalculating
                        ? null
                        : (isNavigating ? onClearRoute : onNavigate),
                    icon: Icon(
                      isNavigating
                          ? Icons.directions_off
                          : Icons.directions_walk,
                      size: 18,
                    ),
                    label: Text(
                      isCalculating
                          ? 'Routing…'
                          : (isNavigating ? 'Clear Route' : 'Navigate'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isNavigating ? AppColors.textMuted : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardBg,
                    foregroundColor: AppColors.charcoal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  child: const Text('Details',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
