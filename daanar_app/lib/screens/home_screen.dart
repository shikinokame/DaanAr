import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/municipality.dart';
import '../models/trail.dart';
import '../providers/landmark_providers.dart';
import '../providers/municipality_providers.dart';
import '../providers/trail_providers.dart';
import '../widgets/archival.dart';
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
  final _searchFocus = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: PaperBackground(
          child: CustomScrollView(
            slivers: [
              // Masthead + search
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _Masthead(topInset: MediaQuery.paddingOf(context).top),
                    Transform.translate(
                      offset: const Offset(0, -26),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _ArchiveSearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          hasQuery: _searchQuery.isNotEmpty,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim().toLowerCase()),
                          onClear: _clearSearch,
                        ),
                      ),
                    ),
                    if (isOffline)
                      Transform.translate(
                        offset: const Offset(0, -12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: OfflineBanner(
                            onRetry: () {
                              ref.invalidate(featuredLandmarksProvider);
                              ref.invalidate(landmarkListProvider);
                              ref.invalidate(municipalityListProvider);
                              ref.invalidate(trailListProvider);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (_searchQuery.isNotEmpty)
                SliverToBoxAdapter(child: _buildSearchResults(allAsync))
              else ...[
                // Featured Landmarks
                SliverToBoxAdapter(
                  child: SectionHeader(
                    eyebrow: "Curator's Selection",
                    title: 'Featured Landmarks',
                    actionLabel: 'View all',
                    onAction: () => context.go('/trails'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 14),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 322,
                    child: featuredAsync.when(
                      loading: () => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: 3,
                        itemBuilder: (_, _) => Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: ShimmerCard(
                            height: 312,
                            width: 262,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      error: (_, _) => const _EmptyNote('Featured landmarks unavailable.'),
                      data: (result) => result.landmarks.isEmpty
                          ? const _EmptyNote('No featured landmarks yet.')
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(18, 2, 4, 8),
                              itemCount: result.landmarks.length,
                              itemBuilder: (_, i) =>
                                  FeaturedLandmarkCard(landmark: result.landmarks[i]),
                            ),
                    ),
                  ),
                ),

                // Explore by Place
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    eyebrow: 'Choose your path',
                    title: 'Explore by Place',
                  ),
                ),
                SliverToBoxAdapter(
                  child: municipalitiesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: ShimmerCard(height: 96),
                    ),
                    error: (_, _) => const _EmptyNote('Places unavailable.'),
                    data: (result) => _PlaceLedger(
                      municipalities: result.municipalities,
                      onTap: (m) {
                        ref.read(landmarkFilterProvider.notifier).setMunicipality(m.name);
                        context.go('/trails');
                      },
                    ),
                  ),
                ),

                // Walking routes
                SliverToBoxAdapter(
                  child: trailsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.fromLTRB(18, 28, 18, 0),
                      child: ShimmerCard(height: 150),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (result) => _RoutesSection(
                      trails: result.trails,
                      onOpen: (t) => context.push('/trails/${t.id}'),
                    ),
                  ),
                ),

                // Colophon
                const SliverToBoxAdapter(child: _Colophon()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<LandmarkResult> allAsync) {
    return allAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, _) => const _EmptyNote('Search is unavailable right now.'),
      data: (result) {
        final filtered = result.landmarks
            .where((l) =>
                l.name.toLowerCase().contains(_searchQuery) ||
                (l.municipality?.name.toLowerCase().contains(_searchQuery) ?? false))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              eyebrow: 'Index',
              title: filtered.isEmpty
                  ? 'No records found'
                  : '${filtered.length} ${filtered.length == 1 ? 'record' : 'records'} found',
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            ),
            if (filtered.isEmpty)
              const _EmptyNote('Try another landmark or town name.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.rule),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divider),
                        _SearchResultRow(landmark: filtered[i]),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// Masthead

class _Masthead extends StatelessWidget {
  final double topInset;
  const _Masthead({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inkDeep, AppColors.primary],
        ),
      ),
      padding: EdgeInsets.fromLTRB(12, topInset + 10, 12, 12),
      child: Stack(
        children: [
          // Faint compass-rose watermark (cartographic mark)
          Positioned(
            right: -30,
            top: -20,
            child: Icon(
              Icons.explore_outlined,
              size: 170,
              color: AppColors.brass.withValues(alpha: 0.06),
            ),
          ),
          EngravedFrame(
            color: AppColors.brass.withValues(alpha: 0.55),
            inset: 4,
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 50),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Text(
                    'PANGASINAN HERITAGE GUIDE',
                    style: AppText.eyebrow.copyWith(
                      color: AppColors.brass,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'DaanAR',
                    child: ExcludeSemantics(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 60,
                            height: 1.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.surface,
                          ),
                          children: [
                            TextSpan(text: 'Daan'),
                            TextSpan(
                              text: 'AR',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppColors.brass,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const OrnamentDivider(width: 132),
                  const SizedBox(height: 10),
                  Text(
                    'Walk the paths of memory',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontStyle: FontStyle.italic,
                      fontSize: 17,
                      color: AppColors.surface.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Search

class _ArchiveSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ArchiveSearchField({
    required this.controller,
    required this.focusNode,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return CornerMarks(
      color: AppColors.brassInk,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.rule),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A2210).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: AppColors.charcoal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => focusNode.unfocus(),
                cursorColor: AppColors.ink,
                style: const TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search the archives…',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: AppColors.divider),
            hasQuery
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  )
                : TextButton(
                    onPressed: () => focusNode.requestFocus(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(56, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      'FIND',
                      style: AppText.action.copyWith(color: AppColors.brassInk),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final Landmark landmark;
  const _SearchResultRow({required this.landmark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/landmarks/${landmark.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                landmark.id.toString().padLeft(2, '0'),
                style: AppText.folio.copyWith(fontSize: 16),
              ),
            ),
            Icon(categoryIcon(landmark.category), size: 18, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    landmark.name,
                    style: AppText.cardTitle.copyWith(fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (landmark.municipality?.name ?? 'Pangasinan').toUpperCase(),
                    style: AppText.meta,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

// Explore by place numbered 2-column ledger

class _PlaceLedger extends StatelessWidget {
  final List<Municipality> municipalities;
  final ValueChanged<Municipality> onTap;

  const _PlaceLedger({required this.municipalities, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (municipalities.isEmpty) return const _EmptyNote('No places yet.');

    final rows = <Widget>[];
    for (var i = 0; i < municipalities.length; i += 2) {
      final left = municipalities[i];
      final right = i + 1 < municipalities.length ? municipalities[i + 1] : null;
      if (i > 0) rows.add(const Divider(height: 1, thickness: 1, color: AppColors.divider));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(i + 1, left)),
              const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
              Expanded(
                child: right == null ? const SizedBox.shrink() : _cell(i + 2, right),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.rule),
        ),
        child: Column(children: rows),
      ),
    );
  }

  Widget _cell(int index, Municipality m) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(
                  index.toString().padLeft(2, '0'),
                  style: AppText.folio.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.name,
                    style: AppText.cardTitle.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (m.landmarksCount != null)
                  Text('${m.landmarksCount}', style: AppText.meta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Walking routes

class _RoutesSection extends StatelessWidget {
  final List<Trail> trails;
  final ValueChanged<Trail> onOpen;

  const _RoutesSection({required this.trails, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) return const SizedBox.shrink();
    final featured = trails.first;
    final others = trails.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _FeaturedRouteCard(trail: featured, index: 1, onTap: () => onOpen(featured)),
        ),
        if (others.isNotEmpty) ...[
          const SectionHeader(
            eyebrow: 'The walking routes',
            title: 'More Heritage Trails',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.rule),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < others.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.divider),
                    _RouteRow(trail: others[i], index: i + 2, onTap: () => onOpen(others[i])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedRouteCard extends StatelessWidget {
  final Trail trail;
  final int index;
  final VoidCallback onTap;

  const _FeaturedRouteCard({required this.trail, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = [
      '${trail.stopCount} ${trail.stopCount == 1 ? 'stop' : 'stops'}',
      trail.distanceLabel,
      trail.durationLabel,
    ].join('  •  ').toUpperCase();

    return Material(
      color: AppColors.inkDeep,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(
                Icons.route_outlined,
                size: 150,
                color: AppColors.brass.withValues(alpha: 0.07),
              ),
            ),
            EngravedFrame(
              color: AppColors.brass.withValues(alpha: 0.5),
              inset: 4,
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              index.toString().padLeft(2, '0'),
                              style: AppText.folio.copyWith(
                                color: AppColors.brass,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'FEATURED WALKING ROUTE',
                                style: AppText.eyebrow.copyWith(
                                  color: AppColors.brass,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          trail.name,
                          style: AppText.sectionTitle.copyWith(
                            color: AppColors.surface,
                            fontSize: 28,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          meta,
                          style: AppText.meta.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.brass,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: AppColors.inkDeep),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final Trail trail;
  final int index;
  final VoidCallback onTap;

  const _RouteRow({required this.trail, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: AppText.folio.copyWith(fontSize: 18),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trail.name,
                    style: AppText.cardTitle.copyWith(fontSize: 19),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trail.stopCount} stops  •  ${trail.durationLabel}  •  ${trail.difficulty}'
                        .toUpperCase(),
                    style: AppText.meta,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

// Small pieces

class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 36, 20, 28),
      child: Column(
        children: [
          OrnamentDivider(color: AppColors.rule, width: 110),
          SizedBox(height: 10),
          Text(
            'District IV · Pangasinan, Philippines',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppFonts.serif,
          fontStyle: FontStyle.italic,
          fontSize: 16,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
