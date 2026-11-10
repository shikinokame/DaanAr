import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/landmark_providers.dart';
import '../services/history_service.dart';
import '../widgets/archival.dart';

enum _HistoryFilter { all, visits, arViewed }

class FieldHistoryScreen extends ConsumerStatefulWidget {
  const FieldHistoryScreen({super.key});

  @override
  ConsumerState<FieldHistoryScreen> createState() => _FieldHistoryScreenState();
}

class _FieldHistoryScreenState extends ConsumerState<FieldHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HistoryService.instance.revision.addListener(_onHistoryChanged);
    _loadHistory();
  }

  @override
  void dispose() {
    HistoryService.instance.revision.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    _loadHistory();
  }

  Future<void> _loadHistory({List<Landmark>? knownLandmarks}) async {
    final landmarks =
        knownLandmarks ?? ref.read(landmarkListProvider).valueOrNull?.landmarks;
    final items = await HistoryService.instance.loadEntries(
      knownLandmarks: landmarks,
    );
    if (!mounted) return;
    setState(() {
      _entries = items;
      _loading = false;
    });
  }

  Future<void> _confirmClearHistory() async {
    if (_entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.rule),
        ),
        title: Text(
          'Clear Field History',
          style: AppText.cardTitle.copyWith(fontSize: 22),
        ),
        content: const Text(
          'Are you sure you want to clear your personal archive of visited places and AR views?',
          style: TextStyle(height: 1.5, color: AppColors.charcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9E472A),
              foregroundColor: AppColors.surface,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR ARCHIVE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryService.instance.clearAll();
    }
  }

  List<HistoryEntry> get _filteredEntries {
    switch (_filter) {
      case _HistoryFilter.all:
        return _entries;
      case _HistoryFilter.visits:
        return _entries
            .where((e) => e.type == HistoryEntryType.visit)
            .toList();
      case _HistoryFilter.arViewed:
        return _entries.where((e) => e.type == HistoryEntryType.ar).toList();
    }
  }

  int get _placesVisitedCount =>
      _entries.where((e) => e.type == HistoryEntryType.visit).length;

  int get _arViewsCount =>
      _entries.where((e) => e.type == HistoryEntryType.ar).length;

  int get _townsExploredCount {
    final towns = <String>{};
    for (final entry in _entries) {
      final normalized = entry.municipalityName.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        towns.add(normalized);
      }
    }
    return towns.length;
  }

  @override
  Widget build(BuildContext context) {
    // Enrich history thumbnails automatically once landmarks finish loading
    ref.listen<AsyncValue<LandmarkResult>>(landmarkListProvider, (prev, next) {
      final list = next.valueOrNull?.landmarks;
      if (list != null && list.isNotEmpty) {
        _loadHistory(knownLandmarks: list);
      }
    });

    final filtered = _filteredEntries;
    final grouped = _groupEntriesByDate(filtered);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PaperBackground(
        child: CustomScrollView(
          slivers: [
            // Archival Header + Overlapping Stats Card
            SliverToBoxAdapter(
              child: _buildHeaderWithLedger(context),
            ),

            // Segmented Filter Bar + CLEAR Action
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: _buildFilterBar(),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = grouped[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == grouped.length - 1 ? 0 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDateHeader(group.label),
                            const SizedBox(height: 12),
                            for (int i = 0; i < group.items.length; i++) ...[
                              _HistoryTimelineCard(
                                entry: group.items[i],
                                onTap: () {
                                  if (group.items[i].landmarkId > 0) {
                                    context.push(
                                      '/landmarks/${group.items[i].landmarkId}',
                                    );
                                  }
                                },
                              ),
                              if (i < group.items.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      );
                    },
                    childCount: grouped.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithLedger(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Deep forest-green archival masthead with inset brass frame
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 38),
          decoration: const BoxDecoration(
            color: AppColors.inkDeep,
            gradient: RadialGradient(
              center: Alignment(-0.55, -0.65),
              radius: 1.35,
              colors: [
                Color(0xFF234D38),
                AppColors.inkDeep,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, topPad + 10, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.32),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR PERSONAL ARCHIVE',
                    textAlign: TextAlign.center,
                    style: AppText.eyebrow.copyWith(
                      color: AppColors.brass,
                      fontSize: 10.5,
                      letterSpacing: 2.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Field History',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surface,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Places explored and stories brought to life',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontStyle: FontStyle.italic,
                      fontSize: 15.5,
                      color: AppColors.surface.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Overlapping 3-column stats ledger card
        Positioned(
          left: 18,
          right: 18,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.rule),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B2110).withValues(alpha: 0.09),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    value: '$_placesVisitedCount',
                    label: 'PLACES VISITED',
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildStatColumn(
                    value: '$_arViewsCount',
                    label: 'AR VIEWS',
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.divider,
                ),
                Expanded(
                  child: _buildStatColumn(
                    value: '$_townsExploredCount',
                    label: 'TOWNS EXPLORED',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.rule),
            ),
            child: Row(
              children: [
                _buildFilterTab('ALL', _HistoryFilter.all),
                _buildFilterTab('VISITS', _HistoryFilter.visits),
                _buildFilterTab('AR VIEWED', _HistoryFilter.arViewed),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        InkWell(
          onTap: _entries.isEmpty ? null : _confirmClearHistory,
          borderRadius: BorderRadius.circular(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'CLEAR',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _entries.isEmpty
                    ? AppColors.textMuted.withValues(alpha: 0.4)
                    : const Color(0xFF9E472A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String label, _HistoryFilter tab) {
    final selected = _filter == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = tab),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.25,
              color: selected ? AppColors.surface : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.brassInk,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.rule.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final String emptyTitle;
    final String emptySubtitle;
    switch (_filter) {
      case _HistoryFilter.visits:
        emptyTitle = 'No Visited Places Yet';
        emptySubtitle =
            'Explore heritage landmarks across Pangasinan to build your personal field history.';
      case _HistoryFilter.arViewed:
        emptyTitle = 'No AR Views Recorded Yet';
        emptySubtitle =
            'Launch 3D reconstructions and AR experiences on landmark pages to log them here.';
      case _HistoryFilter.all:
        emptyTitle = 'Your Field Archive is Empty';
        emptySubtitle =
            'Places you visit and 3D or AR reconstructions you inspect will appear here chronologically.';
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.rule),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.history_edu_outlined,
                color: AppColors.brassInk,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: AppText.cardTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13.5,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupEntriesByDate(List<HistoryEntry> items) {
    final Map<String, List<HistoryEntry>> map = {};
    final List<String> order = [];

    for (final entry in items) {
      final label = _formatDateGroupLabel(entry.timestamp);
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(entry);
    }

    return order
        .map((label) => _DateGroup(label: label, items: map[label]!))
        .toList();
  }

  String _formatDateGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) return 'TODAY';
    if (diffDays == 1) return 'YESTERDAY';

    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final m = months[(dt.month - 1).clamp(0, 11)];
    return '${dt.day} $m ${dt.year}';
  }
}

class _DateGroup {
  final String label;
  final List<HistoryEntry> items;

  const _DateGroup({required this.label, required this.items});
}

class _HistoryTimelineCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTimelineCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = entry.type == HistoryEntryType.ar;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.rule),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2B2110).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail with top-left dark green icon badge
              SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ArchivalPhoto(
                        url: entry.heroImageUrl,
                        sepia: 0.08,
                        placeholderIcon: categoryIcon(entry.category),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.inkDeep,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isAr
                              ? Icons.view_in_ar_outlined
                              : Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.brass,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr ? 'AR EXPERIENCE' : 'VISITED PLACE',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: isAr
                            ? const Color(0xFF9A6B26)
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.landmarkName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 19.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.serif,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: AppColors.textMuted,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${entry.municipalityName.toUpperCase()} · ${_formatTime(entry.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}
