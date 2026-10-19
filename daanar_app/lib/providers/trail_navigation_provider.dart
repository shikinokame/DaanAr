import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrailSessionState {
  final int trailId;
  final int currentStopIndex;
  final Set<int> completedStopIds;
  final Set<int> skippedStopIds;
  final bool isCompleted;

  const TrailSessionState({
    required this.trailId,
    this.currentStopIndex = 0,
    this.completedStopIds = const {},
    this.skippedStopIds = const {},
    this.isCompleted = false,
  });

  TrailSessionState copyWith({
    int? currentStopIndex,
    Set<int>? completedStopIds,
    Set<int>? skippedStopIds,
    bool? isCompleted,
  }) {
    return TrailSessionState(
      trailId: trailId,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      completedStopIds: completedStopIds ?? this.completedStopIds,
      skippedStopIds: skippedStopIds ?? this.skippedStopIds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'trailId': trailId,
        'currentStopIndex': currentStopIndex,
        'completedStopIds': completedStopIds.toList(),
        'skippedStopIds': skippedStopIds.toList(),
        'isCompleted': isCompleted,
      };

  factory TrailSessionState.fromJson(Map<String, dynamic> json) {
    return TrailSessionState(
      trailId: json['trailId'] as int,
      currentStopIndex: json['currentStopIndex'] as int? ?? 0,
      completedStopIds: ((json['completedStopIds'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet(),
      skippedStopIds: ((json['skippedStopIds'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet(),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

final trailNavigationProvider = StateNotifierProvider.family<
    TrailNavigationNotifier, TrailSessionState, int>(
  (ref, trailId) => TrailNavigationNotifier(trailId),
);

class TrailNavigationNotifier extends StateNotifier<TrailSessionState> {
  static String _prefsKey(int trailId) => 'trail_nav_session_$trailId';

  TrailNavigationNotifier(int trailId)
      : super(TrailSessionState(trailId: trailId)) {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(state.trailId));
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = TrailSessionState.fromJson(decoded);
      } catch (_) {
        // Ignore corrupted session
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(state.trailId), jsonEncode(state.toJson()));
  }

  Future<void> selectStop(int index) async {
    state = state.copyWith(currentStopIndex: index, isCompleted: false);
    await _persist();
  }

  Future<void> markStopReached({
    required int landmarkId,
    required int totalStops,
  }) async {
    final updatedCompleted = {...state.completedStopIds, landmarkId};
    final updatedSkipped = {...state.skippedStopIds}..remove(landmarkId);
    final isLast = state.currentStopIndex >= totalStops - 1;

    state = state.copyWith(
      completedStopIds: updatedCompleted,
      skippedStopIds: updatedSkipped,
      currentStopIndex: isLast
          ? state.currentStopIndex
          : state.currentStopIndex + 1,
      isCompleted: isLast,
    );
    await _persist();
  }

  Future<void> skipCurrentStop({
    required int landmarkId,
    required int totalStops,
  }) async {
    final updatedSkipped = {...state.skippedStopIds, landmarkId};
    final isLast = state.currentStopIndex >= totalStops - 1;

    state = state.copyWith(
      skippedStopIds: updatedSkipped,
      currentStopIndex: isLast
          ? state.currentStopIndex
          : state.currentStopIndex + 1,
      isCompleted: isLast,
    );
    await _persist();
  }

  Future<void> resetSession() async {
    state = TrailSessionState(trailId: state.trailId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(state.trailId));
  }
}

