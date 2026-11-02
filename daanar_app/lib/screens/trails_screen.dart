import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/landmark_providers.dart';
import '../providers/municipality_providers.dart';
import '../providers/trail_providers.dart';
import '../widgets/archival.dart';
import '../widgets/landmark_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/shimmer_loading.dart';

class TrailsScreen extends ConsumerWidget {
  const TrailsScreen({super.key});

  static const _categories = [
    'church',
    'park',
    'historical',
    'natural',
    'cultural',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(landmarkFilterProvider);
    final selectedMunicipality = filter.municipality;
    final selectedCategory = filter.category;

    final landmarksAsync = ref.watch(filteredLandmarksProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);
    final trailsAsync = ref.watch(trailListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'PANGASINAN HERITAGE ARCHIVE',
              style: AppText.eyebrow.copyWith(
                color: AppColors.brass,
                fontSize: 9.5,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'Trails & Landmarks',
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ],
        ),
        actions: [
          if (selectedMunicipality != null || selectedCategory != null)
            TextButton(
              onPressed: () =>
                  ref.read(landmarkFilterProvider.notifier).reset(),
              child: Text(
                'CLEAR',
                style: AppText.action.copyWith(color: AppColors.brass),
              ),
            ),
        ],
      ),
      body: PaperBackground(
        child: Column(
          children: [
            if (municipalitiesAsync.whenOrNull(data: (r) => r.fromCache) ==
                    true ||
                landmarksAsync.whenOrNull(data: (r) => r.fromCache) == true ||
                trailsAsync.whenOrNull(data: (r) => r.fromCache) == true)
              OfflineBanner(
                onRetry: () {
                  ref.invalidate(filteredLandmarksProvider);
                  ref.invalidate(municipalityListProvider);
                  ref.invalidate(trailListProvider);
                },
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(filteredLandmarksProvider);
                  ref.invalidate(trailListProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    // Curated Heritage Trails
                    SliverToBoxAdapter(
                      child: trailsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (trailResult) {
                          if (trailResult.trails.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                eyebrow: 'Curated Itineraries',
                                title: 'Guided Walking Routes',
                                padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
                              ),
                              SizedBox(
                                height: 126,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: trailResult.trails.length,
                                  itemBuilder: (context, idx) {
                                    final t = trailResult.trails[idx];
                                    final distKm =
                                        (t.totalDistanceMetres ?? 0) > 0
                                            ? '${(t.totalDistanceMetres! / 1000).toStringAsFixed(1)} KM'
                                            : '${t.landmarks.length} STOPS';
                                    final routeNum =
                                        (idx + 1).toString().padLeft(2, '0');
                                    return GestureDetector(
                                      onTap: () =>
                                          context.push('/trails/${t.id}'),
                                      child: Container(
                                        width: 256,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: EngravedFrame(
                                          fill: AppColors.inkDeep,
                                          color: AppColors.brass
                                              .withValues(alpha: 0.42),
                                          inset: 5,
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    routeNum,
                                                    style: const TextStyle(
                                                      fontFamily:
                                                          AppFonts.serif,
                                                      fontSize: 18,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.brass,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      t.name,
                                                      style: const TextStyle(
                                                        fontFamily:
                                                            AppFonts.serif,
                                                        color:
                                                            AppColors.surface,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 17,
                                                        height: 1.12,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '${t.landmarks.length} STOPS  •  $distKm',
                                                    style: AppText.meta
                                                        .copyWith(
                                                          color: AppColors.brass,
                                                          fontSize: 9.5,
                                                        ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.brass,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 14,
                                                      color: AppColors.inkDeep,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Municipality Filter Ledger
                    SliverToBoxAdapter(
                      child: municipalitiesAsync.when(
                        loading: () => const SizedBox(height: 52),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (result) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                8,
                              ),
                              child: Text(
                                'FILTER BY MUNICIPALITY',
                                style: AppText.eyebrow,
                              ),
                            ),
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  _filterChip(
                                    label: 'All Municipalities',
                                    selected: selectedMunicipality == null,
                                    onTap: () => ref
                                        .read(landmarkFilterProvider.notifier)
                                        .setMunicipality(null),
                                  ),
                                  ...result.municipalities.map(
                                    (m) => _filterChip(
                                      label: m.name,
                                      selected: selectedMunicipality == m.name,
                                      onTap: () => ref
                                          .read(landmarkFilterProvider.notifier)
                                          .setMunicipality(m.name),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Category Filter Ledger
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Text(
                              'CLASSIFICATION',
                              style: AppText.eyebrow,
                            ),
                          ),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              children: [
                                _filterChip(
                                  label: 'All Records',
                                  selected: selectedCategory == null,
                                  onTap: () => ref
                                      .read(landmarkFilterProvider.notifier)
                                      .setCategory(null),
                                ),
                                ..._categories.map(
                                  (c) => _filterChip(
                                    label:
                                        '${c[0].toUpperCase()}${c.substring(1)}',
                                    icon: categoryIcon(c),
                                    selected: selectedCategory == c,
                                    onTap: () => ref
                                        .read(landmarkFilterProvider.notifier)
                                        .setCategory(c),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.divider),
                        ],
                      ),
                    ),

                    // Landmark Catalog Grid
                    landmarksAsync.when(
                      loading: () =>
                          const SliverFillRemaining(child: ShimmerList(count: 6)),
                      error: (e, _) => SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.wifi_off,
                                  size: 44,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Unable to open archive records: $e',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      data: (result) {
                        if (result.landmarks.isEmpty) {
                          return SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.menu_book_outlined,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No archival records match this filter.',
                                    style: TextStyle(
                                      fontFamily: AppFonts.serif,
                                      fontSize: 18,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => ref
                                        .read(landmarkFilterProvider.notifier)
                                        .reset(),
                                    child: Text(
                                      'RESET FILTERS',
                                      style: AppText.action,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 256,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => LandmarkCard(
                                landmark: result.landmarks[i],
                              ),
                              childCount: result.landmarks.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.rule,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 13,
                    color: selected ? AppColors.brass : AppColors.brassInk,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppColors.surface : AppColors.primary,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
