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
  String? _routeError;

  static const _initialPosition = CameraPosition(
    target: LatLng(16.0430, 120.3333),
    zoom: 11.5,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    await ref.read(locationProvider.notifier).requestLocation();
    final locState = ref.read(locationProvider);
    if (locState is LocationReady && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(locState.position.latitude, locState.position.longitude),
          15,
        ),
      );
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

  // ── Routing ─────────────────────────────────────────────────────────────────

  Future<void> _navigateTo(Landmark destination) async {
    // Ensure we have a GPS fix first
    var locState = ref.read(locationProvider);
    if (locState is! LocationReady) {
      await ref.read(locationProvider.notifier).requestLocation();
      locState = ref.read(locationProvider);
    }

    if (locState is! LocationReady) {
      _showSnackBar('Enable location to use navigation.');
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
      _routeError = null;
      _activeRoute = null;
      _routeDestination = destination;
    });

    try {
      final origin = LatLng(
        locState.position.latitude,
        locState.position.longitude,
      );
      final dest = LatLng(destination.lat, destination.lng);

      final route = await RoutingService.getWalkingRoute(
        origin: origin,
        destination: dest,
      );

      setState(() {
        _activeRoute = route;
        _isCalculatingRoute = false;
      });

      // Fit camera to show entire route
      await _fitRouteBounds(origin, dest);
    } on RoutingException catch (e) {
      setState(() {
        _routeError = e.message;
        _isCalculatingRoute = false;
      });
      _showSnackBar(e.message);
    }
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
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _clearRoute() {
    setState(() {
      _activeRoute = null;
      _routeDestination = null;
      _routeError = null;
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heritage Map'),
        actions: [
          if (_activeRoute != null)
            IconButton(
              icon: const Icon(Icons.directions_off),
              tooltip: 'Clear route',
              onPressed: _clearRoute,
            )
          else if (_selectedMunicipality != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _selectedMunicipality = null),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'my_location',
            onPressed: isLocating ? null : _goToMyLocation,
            backgroundColor: Colors.white,
            child: isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────────
          landmarksAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (result) {
              final filtered = _selectedMunicipality == null
                  ? result.landmarks
                  : result.landmarks
                      .where((l) => l.municipality?.name == _selectedMunicipality)
                      .toList();

              final markers = filtered.map((l) {
                final isDestination = _routeDestination?.id == l.id;
                return Marker(
                  markerId: MarkerId(l.id.toString()),
                  position: LatLng(l.lat, l.lng),
                  infoWindow: InfoWindow(title: l.name, snippet: l.category),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    isDestination
                        ? BitmapDescriptor.hueRed
                        : _categoryHue(l.category),
                  ),
                  zIndex: isDestination ? 1 : 0,
                  onTap: () => setState(() => _selectedLandmark = l),
                );
              }).toSet();

              // Blue GPS dot
              final allMarkers = {...markers};
              if (locationState is LocationReady) {
                allMarkers.add(Marker(
                  markerId: const MarkerId('user_location'),
                  position: LatLng(
                    locationState.position.latitude,
                    locationState.position.longitude,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
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
              );
            },
          ),

          // ── Municipality filter chips ────────────────────────────────────────
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

          // ── Route info panel (shows when route is active) ───────────────────
          if (_activeRoute != null)
            Positioned(
              top: 62,
              left: 12,
              right: 12,
              child: _RouteInfoPanel(
                route: _activeRoute!,
                destination: _routeDestination!,
                onClear: _clearRoute,
              ),
            ),

          // ── Route calculating indicator ──────────────────────────────────────
          if (_isCalculatingRoute)
            Positioned(
              top: 62,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          // ── Landmark preview sheet ───────────────────────────────────────────
          if (_selectedLandmark != null)
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
                onClearRoute: _clearRoute,
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
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.divider),
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

// ── Route Info Panel ──────────────────────────────────────────────────────────

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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
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
            // Top row: icon + name + close
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
                          CategoryBadge(
                              category: landmark.category, small: true),
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
            // Bottom row: Navigate + Details buttons
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
                      backgroundColor: isNavigating
                          ? AppColors.textMuted
                          : AppColors.primary,
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
