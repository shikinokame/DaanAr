import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/landmark_providers.dart';
import '../services/ar_service.dart';
import '../services/landmark_service.dart';
import '../services/location_service.dart';
import '../widgets/category_badge.dart';
import '../widgets/offline_banner.dart';
import '../widgets/shimmer_loading.dart';
import 'ar_view_screen.dart';

class LandmarkDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const LandmarkDetailScreen({super.key, required this.id});

  @override
  ConsumerState<LandmarkDetailScreen> createState() =>
      _LandmarkDetailScreenState();
}

class _LandmarkDetailScreenState extends ConsumerState<LandmarkDetailScreen> {
  bool _physicalCheckDone = false;

  @override
  void initState() {
    super.initState();
    // Log PAGE_VIEW when user opens landmark details screen
    Future.microtask(() {
      ref.read(landmarkServiceProvider).logAnalyticsEvent(
            landmarkId: widget.id,
            actionType: 'PAGE_VIEW',
            verificationMethod: 'REMOTE',
          );
    });
  }

  Future<void> _verifyOnSitePresence(Landmark landmark) async {
    if (_physicalCheckDone) return;
    _physicalCheckDone = true;

    try {
      final pos = await LocationService.getCurrentPosition();
      final distance = LocationService.distanceBetween(
        pos.latitude,
        pos.longitude,
        landmark.lat,
        landmark.lng,
      );
      if (distance <= AppConstants.physicalVisitRadiusMetres) {
        await ref.read(landmarkServiceProvider).logAnalyticsEvent(
              landmarkId: landmark.id,
              actionType: 'PHYSICAL_VISIT',
              verificationMethod: 'GPS_GEOFENCE',
              userLat: pos.latitude,
              userLng: pos.longitude,
            );
      }
    } catch (_) {
      // Location unavailable — GeofenceService stream will still handle background checks
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final landmarkAsync = ref.watch(landmarkDetailProvider(id));

    return landmarkAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const ShimmerList(count: 1),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(backgroundColor: AppColors.primary),
        body: Center(child: Text('Error: $e')),
      ),
      data: (result) {
        final landmark = result.landmark;
        _verifyOnSitePresence(landmark);
        final hasImage = landmark.media.heroImage != null;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              if (result.fromCache)
                OfflineBanner(
                  onRetry: () => ref.invalidate(landmarkDetailProvider(id)),
                ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── Parallax Hero Image ─────────────────────────────────
                    SliverAppBar(
                      expandedHeight: 280,
                      pinned: true,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          landmark.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        background: hasImage
                            ? CachedNetworkImage(
                                imageUrl: landmark.media.heroImage!,
                                fit: BoxFit.cover,
                                placeholder: (_, a) => _imagePlaceholder(landmark.category),
                                errorWidget: (_, a, b) => _imagePlaceholder(landmark.category),
                              )
                            : _imagePlaceholder(landmark.category),
                        stretchModes: const [StretchMode.zoomBackground],
                      ),
                    ),

                    // ── Content ─────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges row
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                CategoryBadge(category: landmark.category),
                                if (landmark.era != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      landmark.era!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF7A5C00),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Location
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  _infoRow(Icons.location_city, 'Municipality',
                                      landmark.municipality?.name ?? '—'),
                                  const Divider(height: 16, color: AppColors.divider),
                                  _infoRow(Icons.place_outlined, 'Address', landmark.address),
                                  const Divider(height: 16, color: AppColors.divider),
                                  _infoRow(Icons.my_location, 'Coordinates',
                                      '${landmark.lat.toStringAsFixed(5)}, ${landmark.lng.toStringAsFixed(5)}'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Description
                            const Text(
                              'About This Landmark',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              landmark.description,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.charcoal,
                                height: 1.7,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── View in AR Button ──────────────────────────
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: AppColors.charcoal,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 3,
                                  shadowColor: AppColors.secondary.withValues(alpha: 0.5),
                                ),
                                icon: const Icon(Icons.view_in_ar_rounded, size: 26),
                                label: const Text(
                                  'View in AR',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                onPressed: () {
                                  if (ARService.hasAnyARAsset(landmark)) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ARViewScreen(
                                          landmarkId: landmark.id,
                                          landmarkName: landmark.name,
                                        ),
                                      ),
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: AppColors.cardBg,
                                        title: const Row(
                                          children: [
                                            Icon(Icons.view_in_ar_rounded, color: AppColors.secondary),
                                            SizedBox(width: 8),
                                            Text('AR Experience'),
                                          ],
                                        ),
                                        content: const Text(
                                          'This landmark does not have AR assets uploaded yet.\n\nWould you like to open demo mode instead? (Uses HIRO marker)',
                                          style: TextStyle(height: 1.5),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ARViewScreen(
                                                    landmarkId: landmark.id,
                                                    landmarkName: landmark.name,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.secondary,
                                              foregroundColor: AppColors.charcoal,
                                            ),
                                            child: const Text('Open Demo'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.charcoal)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder(String category) {
    final color = AppColors.categoryColors[category] ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Icon(
          switch (category) {
            'church'    => Icons.church,
            'park'      => Icons.park,
            'historical'=> Icons.account_balance,
            'natural'   => Icons.landscape,
            'cultural'  => Icons.museum,
            _           => Icons.place,
          },
          color: Colors.white.withValues(alpha: 0.4),
          size: 80,
        ),
      ),
    );
  }
}
