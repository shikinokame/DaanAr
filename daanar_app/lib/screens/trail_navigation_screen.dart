import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/route_result.dart';
import '../models/trail.dart';
import '../providers/trail_providers.dart';
import '../providers/location_provider.dart';
import '../providers/trail_navigation_provider.dart';
import '../services/bearing_service.dart';
import '../services/landmark_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/navigation_guidance.dart';
import '../services/route_refresh_policy.dart';
import '../widgets/turn_guidance_banner.dart';
import 'ar_direction_screen.dart';
import 'ar_view_screen.dart';

class TrailNavigationScreen extends ConsumerStatefulWidget {
  final int trailId;

  const TrailNavigationScreen({super.key, required this.trailId});

  @override
  ConsumerState<TrailNavigationScreen> createState() =>
      _TrailNavigationScreenState();
}

class _TrailNavigationScreenState extends ConsumerState<TrailNavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<dynamic>? _posSub;
  LatLng? _livePos;
  final Set<int> _arrivalSheetShownFor = {};

  // Live road-snapped walking route from user's GPS position to current stop
  RouteResult? _liveRoute;
  int? _liveRouteStopId;
  bool _isRoutingLive = false;
  NavigationGuidance? _navGuidance;
  NavigationProgress? _navProgress;
  RouteRefreshPolicy _refreshPolicy = RouteRefreshPolicy();
  double _gpsAccuracy = double.infinity;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _startGpsTracking();
  }

  Future<void> _startGpsTracking() async {
    await ref.read(locationProvider.notifier).requestLocation();
    if (!mounted) return;
    final locState = ref.read(locationProvider);
    if (locState is LocationReady && mounted) {
      final initialPos = LatLng(
        locState.position.latitude,
        locState.position.longitude,
      );
      setState(() {
        _livePos = initialPos;
        _gpsAccuracy = locState.position.accuracy;
      });
      _triggerLiveRouteIfNeeded(initialPos);
    }

    _posSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _livePos = newPos;
        _gpsAccuracy = pos.accuracy;
        _navProgress = _navGuidance?.at(
          newPos,
          previousAlong: _navProgress?.along,
        );
      });
      _checkStopProximity(newPos);
      _triggerLiveRouteIfNeeded(newPos);
    });
  }

  void _triggerLiveRouteIfNeeded(LatLng userPos, {Landmark? explicitStop}) {
    Landmark? targetStop = explicitStop;
    if (targetStop == null) {
      final trail = ref
          .read(trailDetailProvider(widget.trailId))
          .valueOrNull
          ?.trail;
      if (trail == null || trail.landmarks.isEmpty) return;
      final session = ref.read(trailNavigationProvider(widget.trailId));
      final idx = session.currentStopIndex.clamp(0, trail.landmarks.length - 1);
      targetStop = trail.landmarks[idx];
    }

    if (_isRoutingLive) return;
    if (_liveRouteStopId != targetStop.id) {
      _refreshPolicy = RouteRefreshPolicy();
      _liveRoute = null;
      _navGuidance = null;
      _navProgress = null;
    }
    if (_refreshPolicy.shouldRefresh(
      position: userPos,
      destination: LatLng(targetStop.lat, targetStop.lng),
      accuracy: _gpsAccuracy,
      progress: _navProgress,
      now: DateTime.now(),
    )) {
      _fetchLiveWalkRoute(userPos, targetStop);
    }
  }

  Future<void> _fetchLiveWalkRoute(LatLng origin, Landmark stop) async {
    _refreshPolicy.recordAttempt(origin, DateTime.now());
    setState(() {
      _isRoutingLive = true;
      _routeError = null;
      if (_liveRouteStopId != stop.id) {
        _liveRoute = null;
      }
      _liveRouteStopId = stop.id;
    });

    try {
      final route = await RoutingService.getRoute(
        origin: origin,
        destination: LatLng(stop.lat, stop.lng),
      );
      if (!mounted) return;
      final trail = ref
          .read(trailDetailProvider(widget.trailId))
          .valueOrNull
          ?.trail;
      final index = ref
          .read(trailNavigationProvider(widget.trailId))
          .currentStopIndex;
      if (trail == null ||
          index < 0 ||
          index >= trail.landmarks.length ||
          trail.landmarks[index].id != stop.id) {
        return;
      }
      setState(() {
        _navGuidance = NavigationGuidance(route);
        _navProgress = _navGuidance!.at(_livePos ?? origin);
        _liveRoute = route;
        _liveRouteStopId = stop.id;
        _isRoutingLive = false;
      });
    } on RoutingException catch (e) {
      if (mounted) setState(() => _routeError = e.message);
    } finally {
      if (mounted) setState(() => _isRoutingLive = false);
    }
  }

  void _checkStopProximity(LatLng userPos) {
    final trailAsync = ref.read(trailDetailProvider(widget.trailId));
    final trail = trailAsync.valueOrNull?.trail;
    if (trail == null || trail.landmarks.isEmpty) return;

    final session = ref.read(trailNavigationProvider(widget.trailId));
    if (session.isCompleted) return;

    final stopIdx = session.currentStopIndex.clamp(
      0,
      trail.landmarks.length - 1,
    );
    final currentStop = trail.landmarks[stopIdx];
    final dist = BearingService.distanceMetres(
      userPos,
      LatLng(currentStop.lat, currentStop.lng),
    );

    if (dist <= AppConstants.physicalVisitRadiusMetres &&
        !_arrivalSheetShownFor.contains(currentStop.id)) {
      _arrivalSheetShownFor.add(currentStop.id);
      _handleStopArrived(trail, currentStop, stopIdx, userPos: userPos);
    }
  }

  void _handleStopArrived(
    Trail trail,
    Landmark stop,
    int stopIdx, {
    LatLng? userPos,
  }) {
    // Log verified PHYSICAL_VISIT + MAP_NAV to backend analytics
    ref
        .read(landmarkServiceProvider)
        .logAnalyticsEvent(
          landmarkId: stop.id,
          actionType: 'PHYSICAL_VISIT',
          verificationMethod: 'GPS_GEOFENCE',
          userLat: userPos?.latitude ?? stop.lat,
          userLng: userPos?.longitude ?? stop.lng,
        );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final isLastStop = stopIdx >= trail.landmarks.length - 1;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        color: Colors.green.shade700,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STOP ${stopIdx + 1} OF ${trail.landmarks.length} REACHED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.9,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stop.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stop.shortDescription.isNotEmpty
                      ? stop.shortDescription
                      : stop.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (stop.isArReady) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ARViewScreen(
                            landmarkId: stop.id,
                            landmarkName: stop.name,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.charcoal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.view_in_ar_rounded),
                    label: const Text(
                      'Launch 3D & AR Experience',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(trailNavigationProvider(widget.trailId).notifier)
                        .markStopReached(
                          landmarkId: stop.id,
                          totalStops: trail.landmarks.length,
                        );
                    if (!isLastStop) {
                      final nextStop = trail.landmarks[stopIdx + 1];
                      _focusStop(nextStop);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isLastStop
                        ? Icons.emoji_events_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    isLastStop
                        ? 'Complete Heritage Trail'
                        : 'Continue to Stop ${stopIdx + 2}: ${trail.landmarks[stopIdx + 1].name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _focusStop(Landmark stop) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(stop.lat, stop.lng), 15.2),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trailAsync = ref.watch(trailDetailProvider(widget.trailId));
    final session = ref.watch(trailNavigationProvider(widget.trailId));

    return Scaffold(
      body: trailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading trail: $e')),
        data: (result) {
          final trail = result.trail;
          final stops = trail.landmarks;
          if (stops.isEmpty) {
            return const Center(child: Text('This trail has no stops yet.'));
          }

          final currentIdx = session.currentStopIndex.clamp(
            0,
            stops.length - 1,
          );
          final currentStop = stops[currentIdx];
          final currentTarget = LatLng(currentStop.lat, currentStop.lng);

          // Ensure live road-snapped route is fetched whenever GPS + stop are ready
          if (_livePos != null &&
              (_liveRouteStopId != currentStop.id ||
                  (_liveRoute == null && !_isRoutingLive))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _livePos != null) {
                _triggerLiveRouteIfNeeded(_livePos!, explicitStop: currentStop);
              }
            });
          }

          final hasLiveRouteForStop =
              _liveRoute != null && _liveRouteStopId == currentStop.id;
          if (hasLiveRouteForStop &&
              !identical(_navGuidance?.route, _liveRoute)) {
            _navGuidance = NavigationGuidance(_liveRoute!);
            _navProgress = _livePos == null
                ? null
                : _navGuidance!.at(_livePos!);
          }
          if (!hasLiveRouteForStop) {
            _navGuidance = null;
            _navProgress = null;
          }
          final activeRoutePoints = hasLiveRouteForStop
              ? _navGuidance!.remainingPoints(
                  _gpsAccuracy <= 40 ? _navProgress : null,
                )
              : const <LatLng>[];
          final nextInstruction =
              _navProgress?.step?.instruction ??
              'Follow the highlighted road route';
          final distMetres =
              _navProgress?.remaining ??
              _navGuidance?.route.distanceMetres ??
              0;
          final etaLabel =
              _navProgress?.etaLabel ??
              _navGuidance?.route.etaLabel ??
              'Locating GPS';

          final markers = <Marker>{
            for (int i = 0; i < stops.length; i++)
              Marker(
                markerId: MarkerId('nav_stop_${stops[i].id}'),
                position: LatLng(stops[i].lat, stops[i].lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  session.completedStopIds.contains(stops[i].id)
                      ? BitmapDescriptor.hueGreen
                      : (i == currentIdx
                            ? BitmapDescriptor.hueAzure
                            : BitmapDescriptor.hueOrange),
                ),
                infoWindow: InfoWindow(
                  title: 'Stop ${i + 1}: ${stops[i].name}',
                  snippet: stops[i].municipality?.name ?? stops[i].address,
                ),
                onTap: () {
                  ref
                      .read(trailNavigationProvider(widget.trailId).notifier)
                      .selectStop(i);
                },
              ),
          };

          final polylines = <Polyline>{
            // Faint full trail polyline
            if (trail.fullPolylinePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('full_trail_bg'),
                points: trail.fullPolylinePoints,
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 4,
              ),
            // Highlighted road-snapped active route leg (never a 2-point straight line)
            if (activeRoutePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('active_trail_leg'),
                points: activeRoutePoints,
                color: AppColors.secondary,
                width: 6,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
          };

          return Stack(
            children: [
              // Full-screen Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: currentTarget,
                  zoom: 14.5,
                ),
                markers: markers,
                polylines: polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (ctrl) => _mapController = ctrl,
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inkDeep,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.surface,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                session.isCompleted
                                    ? 'Trail completed'
                                    : 'Stop ${currentIdx + 1} of ${stops.length}: ${currentStop.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${BearingService.formatDistance(distMetres)} - $etaLabel',
                              style: const TextStyle(
                                color: AppColors.brass,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!session.isCompleted)
                        TurnGuidanceBanner(
                          progress: _gpsAccuracy <= 40 ? _navProgress : null,
                          route: hasLiveRouteForStop ? _liveRoute : null,
                          error: _routeError,
                          rerouting: _isRoutingLive,
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom Trail Control Sheet
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stop Progress Dots
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: stops.length,
                            separatorBuilder: (_, index) => const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.more_horiz,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            itemBuilder: (_, i) {
                              final s = stops[i];
                              final done = session.completedStopIds.contains(
                                s.id,
                              );
                              final active = i == currentIdx;
                              return InkWell(
                                onTap: () {
                                  ref
                                      .read(
                                        trailNavigationProvider(
                                          widget.trailId,
                                        ).notifier,
                                      )
                                      .selectStop(i);
                                  _focusStop(s);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: done
                                        ? Colors.green.shade600
                                        : (active
                                              ? AppColors.primary
                                              : AppColors.background),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Stop ${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: (done || active)
                                          ? Colors.white
                                          : AppColors.charcoal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons Row: AR Wayfinder | Arrive | Skip
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ArDirectionScreen(
                                        targetStop: currentStop,
                                        stopNumber: currentIdx + 1,
                                        totalStops: stops.length,
                                        nextInstruction: nextInstruction,
                                        segmentPoints: activeRoutePoints,
                                        route: _navGuidance?.route,
                                        onMarkArrived: () => _handleStopArrived(
                                          trail,
                                          currentStop,
                                          currentIdx,
                                          userPos: _livePos,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.explore_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'AR Guide',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _handleStopArrived(
                                  trail,
                                  currentStop,
                                  currentIdx,
                                  userPos: _livePos,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: AppColors.charcoal,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.where_to_vote_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Mark Reached',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Skip Stop',
                              onPressed: () async {
                                await ref
                                    .read(
                                      trailNavigationProvider(
                                        widget.trailId,
                                      ).notifier,
                                    )
                                    .skipCurrentStop(
                                      landmarkId: currentStop.id,
                                      totalStops: stops.length,
                                    );
                                if (currentIdx + 1 < stops.length) {
                                  _focusStop(stops[currentIdx + 1]);
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.background,
                              ),
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
