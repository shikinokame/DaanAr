import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/trail.dart';
import '../providers/trail_providers.dart';
import '../providers/trail_navigation_provider.dart';
import '../widgets/shimmer_loading.dart';
import 'ar_view_screen.dart';

class TrailDetailScreen extends ConsumerStatefulWidget {
  final int trailId;

  const TrailDetailScreen({super.key, required this.trailId});

  @override
  ConsumerState<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends ConsumerState<TrailDetailScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _fitTrailBounds(Trail trail) {
    final pts = trail.fullPolylinePoints;
    if (pts.isEmpty || _mapController == null) return;

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 0.001 && (maxLng - minLng).abs() < 0.001) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(pts.first, 15),
      );
      return;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trailAsync = ref.watch(trailDetailProvider(widget.trailId));
    final session = ref.watch(trailNavigationProvider(widget.trailId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Heritage Trail'),
        actions: [
          if (session.completedStopIds.isNotEmpty ||
              session.skippedStopIds.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref
                    .read(trailNavigationProvider(widget.trailId).notifier)
                    .resetSession();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
              label: const Text(
                'Reset Progress',
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
            ),
        ],
      ),
      body: trailAsync.when(
        loading: () => const ShimmerList(count: 4),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Could not load trail: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        data: (result) {
          final trail = result.trail;
          final stops = trail.landmarks;
          final polylinePoints = trail.fullPolylinePoints;

          final markers = <Marker>{
            for (int i = 0; i < stops.length; i++)
              Marker(
                markerId: MarkerId('trail_stop_${stops[i].id}'),
                position: LatLng(stops[i].lat, stops[i].lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  session.completedStopIds.contains(stops[i].id)
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(
                  title: 'Stop ${i + 1}: ${stops[i].name}',
                  snippet: stops[i].municipality?.name ?? stops[i].address,
                ),
              ),
          };

          final polylines = <Polyline>{
            if (polylinePoints.length >= 2)
              Polyline(
                polylineId: const PolylineId('trail_preview_line'),
                points: polylinePoints,
                color: AppColors.primary,
                width: 5,
              ),
          };

          final initialTarget = stops.isNotEmpty
              ? LatLng(stops.first.lat, stops.first.lng)
              : const LatLng(16.0432, 120.3338);

          final hasProgress = session.completedStopIds.isNotEmpty ||
              session.currentStopIndex > 0;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Map Preview with Numbered Stops & Route Polyline ──
                    SizedBox(
                      height: 230,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: initialTarget,
                              zoom: 12.2,
                            ),
                            markers: markers,
                            polylines: polylines,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (ctrl) {
                              _mapController = ctrl;
                              Future.delayed(
                                const Duration(milliseconds: 250),
                                () => _fitTrailBounds(trail),
                              );
                            },
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.92,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                trail.coverageLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Trail Header & Key Metrics ────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      color: AppColors.cardBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trail.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trail.description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _MetricChip(
                                icon: Icons.flag_rounded,
                                label: '${stops.length} Stops',
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                icon: Icons.route_rounded,
                                label: trail.distanceLabel,
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                icon: Icons.schedule_rounded,
                                label: trail.durationLabel,
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                icon: Icons.terrain_rounded,
                                label: trail.difficulty.toUpperCase(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: AppColors.divider),

                    // ── Ordered Stops Timeline ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ordered Trail Stops',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                          Text(
                            '${session.completedStopIds.length} of ${stops.length} visited',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...List.generate(stops.length, (i) {
                      final stop = stops[i];
                      final isDone = session.completedStopIds.contains(stop.id);
                      final isCurrent = session.currentStopIndex == i &&
                          !session.isCompleted;
                      final nextSeg = trail.segmentToStop(i + 1);

                      return _TrailStopCard(
                        stopNumber: i + 1,
                        landmark: stop,
                        isCompleted: isDone,
                        isCurrent: isCurrent,
                        nextSegment: nextSeg,
                        onTapLandmark: () =>
                            context.push('/landmarks/${stop.id}'),
                        onLaunchAr: stop.isArReady
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ARViewScreen(
                                      landmarkId: stop.id,
                                      landmarkName: stop.name,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    }),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ── Sticky Start / Resume Trail CTA ─────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: stops.isEmpty
                          ? null
                          : () => context.push(
                              '/trails/${trail.id}/navigate',
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(
                        hasProgress && !session.isCompleted
                            ? 'Resume Trail (Stop ${session.currentStopIndex + 1} of ${stops.length})'
                            : 'Start Guided Heritage Trail',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailStopCard extends StatelessWidget {
  final int stopNumber;
  final Landmark landmark;
  final bool isCompleted;
  final bool isCurrent;
  final TrailSegment? nextSegment;
  final VoidCallback onTapLandmark;
  final VoidCallback? onLaunchAr;

  const _TrailStopCard({
    required this.stopNumber,
    required this.landmark,
    required this.isCompleted,
    required this.isCurrent,
    required this.nextSegment,
    required this.onTapLandmark,
    this.onLaunchAr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapLandmark,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppColors.primary
                      : (isCompleted
                          ? Colors.green.shade400
                          : AppColors.divider),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade600
                          : (isCurrent
                              ? AppColors.primary
                              : AppColors.secondary),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : Text(
                            '$stopNumber',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.charcoal,
                            ),
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
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          landmark.municipality?.name ?? landmark.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onLaunchAr != null)
                    IconButton(
                      onPressed: onLaunchAr,
                      tooltip: 'View 3D / AR',
                      icon: const Icon(
                        Icons.view_in_ar_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          if (nextSegment != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 22,
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.directions_car_filled_outlined,
                    size: 14,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Next leg: ${nextSegment!.distanceLabel} • ~${nextSegment!.durationLabel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}
