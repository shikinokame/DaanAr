import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/trail.dart';
import '../providers/trail_providers.dart';
import '../providers/location_provider.dart';
import '../providers/trail_navigation_provider.dart';
import '../services/bearing_service.dart';
import '../services/landmark_service.dart';
import '../services/location_service.dart';
import 'ar_direction_screen.dart';
import 'ar_view_screen.dart';

class TrailNavigationScreen extends ConsumerStatefulWidget {
  final int trailId;

  const TrailNavigationScreen({super.key, required this.trailId});

  @override
  ConsumerState<TrailNavigationScreen> createState() =>
      _TrailNavigationScreenState();
}

class _TrailNavigationScreenState
    extends ConsumerState<TrailNavigationScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<dynamic>? _posSub;
  LatLng? _livePos;
  final Set<int> _arrivalSheetShownFor = {};

  @override
  void initState() {
    super.initState();
    _startGpsTracking();
  }

  Future<void> _startGpsTracking() async {
    await ref.read(locationProvider.notifier).requestLocation();
    final locState = ref.read(locationProvider);
    if (locState is LocationReady && mounted) {
      setState(() {
        _livePos = LatLng(
          locState.position.latitude,
          locState.position.longitude,
        );
      });
    }

    _posSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _livePos = newPos);
      _checkStopProximity(newPos);
    });
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
    ref.read(landmarkServiceProvider).logAnalyticsEvent(
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

          final activeSegment = trail.segmentToStop(currentIdx);
          final nextInstruction =
              activeSegment != null && activeSegment.steps.isNotEmpty
                  ? activeSegment.steps.first.instruction
                  : 'Proceed toward ${currentStop.name}';

          final distMetres = _livePos != null
              ? BearingService.distanceMetres(_livePos!, currentTarget)
              : (activeSegment?.distanceM.toDouble() ?? 450.0);

          final etaLabel = BearingService.formatEta(
            distMetres,
            walking: trail.municipality != null,
          );

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
            // Highlighted active segment
            if (activeSegment != null && activeSegment.points.length >= 2)
              Polyline(
                polylineId: const PolylineId('active_trail_leg'),
                points: activeSegment.points,
                color: AppColors.secondary,
                width: 6,
              )
            else if (_livePos != null)
              Polyline(
                polylineId: const PolylineId('live_to_stop_line'),
                points: [_livePos!, currentTarget],
                color: AppColors.secondary,
                width: 5,
              ),
          };

          return Stack(
            children: [
              // ── Full-screen Google Map ──────────────────────────────────
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

              // ── Top Guidance Banner ─────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                session.isCompleted
                                    ? 'TRAIL COMPLETED • ${trail.name.toUpperCase()}'
                                    : 'STOP ${currentIdx + 1} OF ${stops.length} • ${(currentStop.municipality?.name ?? trail.coverageLabel).toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            Text(
                              '${BearingService.formatDistance(distMetres)} • $etaLabel',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.turn_right_rounded,
                                color: AppColors.secondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentStop.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nextInstruction,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Trail Control Sheet ──────────────────────────────
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
                            separatorBuilder: (_, _1) => const Padding(
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
