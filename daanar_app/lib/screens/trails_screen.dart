import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/landmark_providers.dart';
import '../providers/municipality_providers.dart';
import '../widgets/landmark_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/shimmer_loading.dart';

class TrailsScreen extends ConsumerStatefulWidget {
  const TrailsScreen({super.key});

  @override
  ConsumerState<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends ConsumerState<TrailsScreen> {
  String? _selectedMunicipality;
  String? _selectedCategory;

  static const _categories = [
    'church', 'park', 'historical', 'natural', 'cultural',
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksAsync = ref.watch(filteredLandmarksProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Landmarks'),
        actions: [
          if (_selectedMunicipality != null || _selectedCategory != null)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear', style: TextStyle(color: AppColors.secondary)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Show offline banner when serving cached data
          if (municipalitiesAsync.whenOrNull(data: (r) => r.fromCache) == true ||
              landmarksAsync.whenOrNull(data: (r) => r.fromCache) == true)
            OfflineBanner(
              onRetry: () {
                ref.invalidate(filteredLandmarksProvider);
                ref.invalidate(municipalityListProvider);
              },
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(filteredLandmarksProvider),
              child: CustomScrollView(
          slivers: [
            // ── Municipality chips ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: municipalitiesAsync.when(
                loading: () => const SizedBox(height: 52),
                error: (_, _1) => const SizedBox.shrink(),
                data: (result) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text('Location', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted, letterSpacing: 0.8,
                      )),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _chip('All', _selectedMunicipality == null, () => _setMunicipality(null)),
                          ...result.municipalities.map((m) => _chip(
                            m.name,
                            _selectedMunicipality == m.name,
                            () => _setMunicipality(m.name),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category chips ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text('Category', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textMuted, letterSpacing: 0.8,
                    )),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _chip('All', _selectedCategory == null, () => _setCategory(null)),
                        ..._categories.map((c) => _chip(
                          '${_catEmoji(c)} ${c[0].toUpperCase()}${c.substring(1)}',
                          _selectedCategory == c,
                          () => _setCategory(c),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.divider),
                ],
              ),
            ),

            // ── Landmark grid ───────────────────────────────────────────────
            landmarksAsync.when(
              loading: () => const SliverFillRemaining(child: ShimmerList(count: 6)),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Failed to load: $e',
                          style: const TextStyle(color: AppColors.textMuted),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              data: (result) {
                if (result.landmarks.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 56, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('No landmarks found for this filter.',
                              style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(14),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => LandmarkCard(landmark: result.landmarks[i]),
                      childCount: result.landmarks.length,
                    ),
                  ),
                );
              },
            ),
          ],
              ),   // CustomScrollView
            ),     // RefreshIndicator
          ),       // Expanded
        ],
      ),           // Column
    );             // Scaffold
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.charcoal,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
        ),
        backgroundColor: AppColors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  void _setMunicipality(String? value) {
    setState(() => _selectedMunicipality = value);
    ref.read(landmarkFilterProvider.notifier).setMunicipality(value);
  }

  void _setCategory(String? value) {
    setState(() => _selectedCategory = value);
    ref.read(landmarkFilterProvider.notifier).setCategory(value);
  }

  void _clearFilters() {
    setState(() {
      _selectedMunicipality = null;
      _selectedCategory = null;
    });
    ref.read(landmarkFilterProvider.notifier).reset();
  }

  String _catEmoji(String cat) => switch (cat) {
    'church'    => '⛪',
    'park'      => '🌳',
    'historical'=> '🏛',
    'natural'   => '🏞',
    'cultural'  => '🎭',
    _           => '📍',
  };
}
