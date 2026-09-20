import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/landmark_providers.dart';
import '../providers/municipality_providers.dart';
import '../providers/trail_providers.dart';
import '../widgets/featured_landmark_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(featuredLandmarksProvider);
    final allAsync = ref.watch(landmarkListProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);
    final trailsAsync = ref.watch(trailListProvider);

    // Show offline banner if ANY data source is from cache
    final isOffline = [
      featuredAsync.whenOrNull(data: (r) => r.fromCache) ?? false,
      allAsync.whenOrNull(data: (r) => r.fromCache) ?? false,
      municipalitiesAsync.whenOrNull(data: (r) => r.fromCache) ?? false,
      trailsAsync.whenOrNull(data: (r) => r.fromCache) ?? false,
    ].any((v) => v);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (isOffline)
            OfflineBanner(
              onRetry: () {
                ref.invalidate(featuredLandmarksProvider);
                ref.invalidate(landmarkListProvider);
                ref.invalidate(municipalityListProvider);
                ref.invalidate(trailListProvider);
              },
            ),
          Expanded(
            child: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 130,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'DaanAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF2D6A4F)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.08,
                    child: Icon(Icons.account_balance,
                        size: 140, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Search Bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search landmarks...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // ── Search results (only when searching) ───────────────────
                if (_searchQuery.isNotEmpty)
                  _buildSearchResults(allAsync)
                else ...[
                  // ── Featured Section ──────────────────────────────────────
                  _sectionTitle('✨ Featured Landmarks', topPad: 22),
                  featuredAsync.when(
                    loading: () => SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 3,
                        itemBuilder: (_, _1) => Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: ShimmerCard(
                            height: 200,
                            width: 220,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (result) => SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: result.landmarks.length,
                        itemBuilder: (_, i) =>
                            FeaturedLandmarkCard(landmark: result.landmarks[i]),
                      ),
                    ),
                  ),

                  // ── Municipality chips ────────────────────────────────────
                  _sectionTitle('📍 Browse by Location', topPad: 24),
                  municipalitiesAsync.when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, _1) => const SizedBox.shrink(),
                    data: (result) => SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: result.municipalities.length,
                        itemBuilder: (_, i) {
                          final m = result.municipalities[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(m.name),
                              backgroundColor: AppColors.cardBg,
                              labelStyle: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              side: const BorderSide(color: AppColors.primary, width: 1),
                              onPressed: () {
                                ref.read(landmarkFilterProvider.notifier)
                                    .setMunicipality(m.name);
                                context.go('/trails');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Heritage Trails ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🗺 Explore Heritage Trails',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/trails'),
                          child: const Text(
                            'See all',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: ShimmerCard(height: 100),
                    ),
                    error: (_, _1) => const SizedBox.shrink(),
                    data: (result) => result.trails.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('No trails yet.', style: TextStyle(color: AppColors.textMuted)),
                          )
                        : SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: result.trails.length,
                              itemBuilder: (_, i) {
                                final t = result.trails[i];
                                return GestureDetector(
                                  onTap: () => context.go('/trails'),
                                  child: Container(
                                    width: 180,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          t.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.timer_outlined,
                                                color: AppColors.secondary, size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${t.estimatedTime} min',
                                              style: const TextStyle(
                                                  color: AppColors.secondary, fontSize: 11),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                t.difficulty,
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),         // CustomScrollView
          ),     // Expanded
        ],
      ),         // Column
    );           // Scaffold
  }

  Widget _buildSearchResults(AsyncValue<LandmarkResult> allAsync) {
    return allAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _1) => const SizedBox.shrink(),
      data: (result) {
        final filtered = result.landmarks
            .where((l) => l.name.toLowerCase().contains(_searchQuery))
            .toList();
        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No landmarks found.', style: TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          itemCount: filtered.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              tileColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: CircleAvatar(
                backgroundColor: AppColors.categoryColors[filtered[i].category] ??
                    AppColors.primary,
                child: Icon(_catIcon(filtered[i].category), color: Colors.white, size: 18),
              ),
              title: Text(filtered[i].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(filtered[i].municipality?.name ?? '', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
              onTap: () => context.push('/landmarks/${filtered[i].id}'),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, {double topPad = 16}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.charcoal,
        ),
      ),
    );
  }

  IconData _catIcon(String cat) => switch (cat) {
    'church'    => Icons.church,
    'park'      => Icons.park,
    'historical'=> Icons.account_balance,
    'natural'   => Icons.landscape,
    'cultural'  => Icons.museum,
    _           => Icons.place,
  };
}
