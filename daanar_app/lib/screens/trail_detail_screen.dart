import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/trail.dart';
import '../providers/trail_providers.dart';
import '../providers/trail_navigation_provider.dart';
import '../widgets/archival.dart';
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
        title: Column(
          children: [
            Text(
              'ITINERARY DOSSIER',
              style: AppText.eyebrow.copyWith(
                color: AppColors.brass,
                fontSize: 9.5,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Heritage Walking Route',
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ],
        ),
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
                size: 15,
                color: AppColors.brass,
              ),
              label: Text(
                'RESET',
                style: AppText.action.copyWith(color: AppColors.brass),
              ),
            ),
        ],
      ),
      body: PaperBackground(
        child: trailAsync.when(
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
                      // ── Map Preview Plate ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: EngravedFrame(
                          fill: AppColors.surface,
                          padding: const EdgeInsets.all(8),
                          child: SizedBox(
                            height: 215,
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
                                  top: 8,
                                  left: 8,
                                  child: ArchivalStamp(
                                    trail.coverageLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Trail Header & Key Metrics ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: EngravedFrame(
                          fill: AppColors.surface,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FolioLabel(trail.id),
                              const SizedBox(height: 6),
                              Text(
                                trail.name,
                                style: const TextStyle(
                                  fontFamily: AppFonts.serif,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                trail.description,
                                style: const TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const OrnamentDivider(),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _MetricChip(
                                    icon: Icons.flag_outlined,
                                    label: '${stops.length} STOPS',
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.route_outlined,
                                    label: trail.distanceLabel.toUpperCase(),
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.schedule_outlined,
                                    label: trail.durationLabel.toUpperCase(),
                                  ),
                                  const SizedBox(width: 8),
                                  _MetricChip(
                                    icon: Icons.terrain_outlined,
                                    label: trail.difficulty.toUpperCase(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Ordered Stops Timeline ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FIELD GUIDE SEQUENCE',
                                  style: AppText.eyebrow,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ordered Trail Stops',
                                  style: AppText.sectionTitle,
                                ),
                              ],
                            ),
                            Text(
                              '${session.completedStopIds.length} OF ${stops.length} VISITED',
                              style: AppText.meta.copyWith(
                                color: AppColors.brassInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      ...List.generate(stops.length, (i) {
                        final stop = stops[i];
                        final isDone =
                            session.completedStopIds.contains(stop.id);
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

                // ── Sticky Start / Resume Trail CTA ──────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.rule, width: 1),
                    ),
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
                          foregroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                            side: const BorderSide(
                              color: AppColors.brass,
                              width: 0.9,
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.explore_outlined,
                          color: AppColors.brass,
                          size: 19,
                        ),
                        label: Text(
                          hasProgress && !session.isCompleted
                              ? 'RESUME TRAIL (STOP ${session.currentStopIndex + 1} OF ${stops.length})'
                              : 'BEGIN GUIDED HERITAGE TRAIL',
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.rule, width: 0.9),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: AppColors.brassInk),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.meta.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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
    final numLabel = stopNumber.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isCurrent ? AppColors.primary : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: BorderSide(
                color: isCurrent
                    ? AppColors.primary
                    : (isCompleted ? AppColors.brassInk : AppColors.rule),
                width: isCurrent ? 1.4 : 1.0,
              ),
            ),
            child: InkWell(
              onTap: onTapLandmark,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primary
                            : (isCurrent
                                ? AppColors.brass
                                : AppColors.background),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.brass
                              : AppColors.rule,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: AppColors.brass,
                            )
                          : Text(
                              numLabel,
                              style: TextStyle(
                                fontFamily: AppFonts.serif,
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: isCurrent
                                    ? AppColors.inkDeep
                                    : AppColors.brassInk,
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
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? AppColors.surface
                                  : AppColors.primary,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (landmark.municipality?.name ?? landmark.address)
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.meta.copyWith(
                              color: isCurrent
                                  ? AppColors.brass
                                  : AppColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onLaunchAr != null)
                      IconButton(
                        onPressed: onLaunchAr,
                        tooltip: 'View 3D / AR',
                        icon: Icon(
                          Icons.view_in_ar_outlined,
                          size: 20,
                          color: isCurrent
                              ? AppColors.brass
                              : AppColors.primary,
                        ),
                      ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: isCurrent ? AppColors.brass : AppColors.brassInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (nextSegment != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6, bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 1,
                    height: 22,
                    color: AppColors.rule,
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.directions_walk_outlined,
                    size: 13,
                    color: AppColors.brassInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'NEXT LEG: ${nextSegment!.distanceLabel.toUpperCase()}  •  ~${nextSegment!.durationLabel.toUpperCase()}',
                    style: AppText.meta.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
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
