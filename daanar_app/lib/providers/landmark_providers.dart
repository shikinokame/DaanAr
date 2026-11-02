import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';

/// Result wrapper so the UI knows whether data came from cache.
class LandmarkResult {
  final List<Landmark> landmarks;
  final bool fromCache;
  const LandmarkResult({required this.landmarks, required this.fromCache});
}

class LandmarkDetailResult {
  final Landmark landmark;
  final bool fromCache;
  const LandmarkDetailResult({required this.landmark, required this.fromCache});
}

/// All landmarks (page 1, no filters).
final landmarkListProvider = FutureProvider<LandmarkResult>((ref) async {
  final service = ref.read(landmarkServiceProvider);
  final result = await service.fetchAll();
  return LandmarkResult(
    landmarks: result['landmarks'] as List<Landmark>,
    fromCache: result['fromCache'] as bool,
  );
});

/// Featured landmarks only.
final featuredLandmarksProvider = FutureProvider<LandmarkResult>((ref) async {
  final service = ref.read(landmarkServiceProvider);
  final result = await service.fetchFeatured();
  return LandmarkResult(landmarks: result.landmarks, fromCache: result.fromCache);
});

/// Single landmark by id.
final landmarkDetailProvider =
    FutureProvider.family<LandmarkDetailResult, int>((ref, id) async {
  final service = ref.read(landmarkServiceProvider);
  final result = await service.fetchById(id);
  return LandmarkDetailResult(
    landmark: result.landmark,
    fromCache: result.fromCache,
  );
});

/// Notifier for filter state (municipality + category).
class LandmarkFilterNotifier extends Notifier<LandmarkFilter> {
  @override
  LandmarkFilter build() => const LandmarkFilter();

  void setMunicipality(String? value) =>
      state = LandmarkFilter(municipality: value, category: state.category);
  void setCategory(String? value) =>
      state = LandmarkFilter(municipality: state.municipality, category: value);
  void reset() => state = const LandmarkFilter();
}

class LandmarkFilter {
  final String? municipality;
  final String? category;

  const LandmarkFilter({this.municipality, this.category});

  LandmarkFilter copyWith({String? municipality, String? category}) =>
      LandmarkFilter(
        municipality: municipality ?? this.municipality,
        category: category ?? this.category,
      );
}

final landmarkFilterProvider =
    NotifierProvider<LandmarkFilterNotifier, LandmarkFilter>(
  LandmarkFilterNotifier.new,
);

/// Filtered landmark list reacts to filter changes.
final filteredLandmarksProvider = FutureProvider<LandmarkResult>((ref) async {
  final filter = ref.watch(landmarkFilterProvider);
  final service = ref.read(landmarkServiceProvider);
  final result = await service.fetchAll(
    municipality: filter.municipality,
    category: filter.category,
  );
  return LandmarkResult(
    landmarks: result['landmarks'] as List<Landmark>,
    fromCache: result['fromCache'] as bool,
  );
});
