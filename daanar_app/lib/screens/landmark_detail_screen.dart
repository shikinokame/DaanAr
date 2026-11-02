import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/landmark_providers.dart';
import '../services/ar_service.dart';
import '../services/landmark_service.dart';
import '../services/location_service.dart';
import '../widgets/archival.dart';
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
  // Default to true color on the detail screen so tourists recognize the site,
  // with a one-tap toggle to view as an archival sepia plate.
  bool _archivalSepia = false;

  @override
  void initState() {
    super.initState();
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
      // Location unavailable GeofenceService stream will still handle background checks
    }
  }

  void _openArExperience(BuildContext context, Landmark landmark) {
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: AppColors.rule),
          ),
          title: Text(
            '3D & AR Field Guide',
            style: AppText.cardTitle.copyWith(fontSize: 22),
          ),
          content: const Text(
            'This landmark does not have custom 3D assets uploaded yet.\n\nWould you like to open the interactive 3D preview mode anyway?',
            style: TextStyle(height: 1.5, color: AppColors.charcoal),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
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
              child: const Text('OPEN 3D VIEW'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final landmarkAsync = ref.watch(landmarkDetailProvider(id));

    return landmarkAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: ShimmerList(count: 1),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Archival Record')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (result) {
        final landmark = result.landmark;
        _verifyOnSitePresence(landmark);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.inkDeep,
            title: Text(
              'Folio No. ${landmark.id.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: AppFonts.serif,
                fontStyle: FontStyle.italic,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: AppColors.brass,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'View in 3D & AR',
                onPressed: () => _openArExperience(context, landmark),
                icon: const Icon(Icons.view_in_ar_outlined, color: AppColors.brass),
              ),
            ],
          ),
          body: PaperBackground(
            child: Column(
              children: [
                if (result.fromCache)
                  OfflineBanner(
                    onRetry: () => ref.invalidate(landmarkDetailProvider(id)),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mounted Archival Plate
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.rule),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A3B1F).withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ArchivalPhoto(
                                        url: landmark.media.heroImage,
                                        sepia: _archivalSepia ? 0.55 : 0.0,
                                        placeholderIcon: categoryIcon(landmark.category),
                                      ),
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: CategoryBadge(category: landmark.category),
                                      ),
                                      if (landmark.era != null && landmark.era!.isNotEmpty)
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: ArchivalStamp(
                                            landmark.era!,
                                            background: AppColors.surface,
                                            foreground: AppColors.inkDeep,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Fig. ${landmark.id.toString().padLeft(2, '0')} ${landmark.municipality?.name ?? 'Pangasinan'} Archive',
                                      style: AppText.folio.copyWith(fontSize: 13.5),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _archivalSepia = !_archivalSepia),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.divider),
                                        color: _archivalSepia ? AppColors.paperDeep : AppColors.surface,
                                      ),
                                      child: Text(
                                        _archivalSepia ? 'SEPIA PLATE' : 'TRUE COLOR',
                                        style: AppText.meta.copyWith(
                                          fontSize: 9.5,
                                          color: AppColors.brassInk,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Editorial Title Header
                        Text(
                          (landmark.municipality?.name ?? 'Pangasinan Heritage').toUpperCase(),
                          style: AppText.eyebrow,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          landmark.name,
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const OrnamentDivider(color: AppColors.brassInk, width: 120),
                        const SizedBox(height: 20),

                        // Primary 3D & AR Launch Plate
                        _ArLaunchPlate(
                          onPressed: () => _openArExperience(context, landmark),
                        ),

                        const SizedBox(height: 24),

                        // Historical Narrative
                        Text('ARCHIVAL RECORD', style: AppText.eyebrow),
                        const SizedBox(height: 4),
                        Text('Historical Background', style: AppText.sectionTitle.copyWith(fontSize: 24)),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.rule),
                          ),
                          child: Text(
                            landmark.description,
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 15,
                              color: AppColors.charcoal,
                              height: 1.75,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Registry & Cartographic Ledger
                        Text('CATALOGUE DATA', style: AppText.eyebrow),
                        const SizedBox(height: 4),
                        Text('Site Registry', style: AppText.sectionTitle.copyWith(fontSize: 24)),
                        const SizedBox(height: 12),
                        EngravedFrame(
                          color: AppColors.rule,
                          fill: AppColors.surface,
                          inset: 4,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _ledgerRow(
                                'MUNICIPALITY',
                                landmark.municipality?.name ?? 'Pangasinan',
                              ),
                              const Divider(height: 18, color: AppColors.divider),
                              _ledgerRow(
                                'CLASSIFICATION',
                                landmark.category.toUpperCase(),
                              ),
                              if (landmark.era != null && landmark.era!.isNotEmpty) ...[
                                const Divider(height: 18, color: AppColors.divider),
                                _ledgerRow('PERIOD / ERA', landmark.era!),
                              ],
                              const Divider(height: 18, color: AppColors.divider),
                              _ledgerRow('ADDRESS', landmark.address),
                              const Divider(height: 18, color: AppColors.divider),
                              _ledgerRow(
                                'COORDINATES',
                                '${landmark.lat.toStringAsFixed(5)}° N, ${landmark.lng.toStringAsFixed(5)}° E',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ledgerRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: AppText.meta.copyWith(
              color: AppColors.brassInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArLaunchPlate extends StatelessWidget {
  final VoidCallback onPressed;
  const _ArLaunchPlate({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inkDeep,
      child: InkWell(
        onTap: onPressed,
        child: EngravedFrame(
          color: AppColors.brass.withValues(alpha: 0.6),
          inset: 4,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.brass.withValues(alpha: 0.7)),
                  color: AppColors.primary,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  color: AppColors.brass,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INTERACTIVE FIELD INSPECTION · OFFLINE READY',
                      style: AppText.eyebrow.copyWith(
                        color: AppColors.brass,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'View in 3D Studio & AR',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.surface,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.brass,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.inkDeep,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
