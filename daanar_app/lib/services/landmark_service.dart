import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../models/landmark.dart';

final landmarkServiceProvider = Provider<LandmarkService>(
  (ref) => LandmarkService(ref.read(apiClientProvider).dio),
);

class LandmarkService {
  final Dio _dio;
  const LandmarkService(this._dio);

  /// GET /api/v1/landmarks
  /// On success: saves response to cache.
  /// On network failure: loads from cache. Throws if no cache exists.
  Future<Map<String, dynamic>> fetchAll({
    String? municipality,
    String? category,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/landmarks',
        queryParameters: {
          'page': page,
          'municipality': municipality,
          'category': category,
        }..removeWhere((_, v) => v == null),
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] as List<dynamic>)
          .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache the raw JSON list for offline use (only for unfiltered, page 1)
      if (municipality == null && category == null && page == 1) {
        final rawList = (data['data'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        await CacheService.saveList(CacheService.keyLandmarks, rawList);
      }

      return {'landmarks': items, 'meta': data['meta'] ?? {}, 'fromCache': false};
    } on DioException {
      // Network failed — try cache
      final cached = await CacheService.loadList(CacheService.keyLandmarks);
      if (cached != null) {
        final items = cached.map(Landmark.fromJson).toList();
        return {'landmarks': items, 'meta': {}, 'fromCache': true};
      }
      rethrow;
    }
  }

  /// GET /api/v1/landmarks/featured
  Future<({List<Landmark> landmarks, bool fromCache})> fetchFeatured() async {
    try {
      final response = await _dio.get('/landmarks/featured');
      final data = response.data as Map<String, dynamic>;
      final rawList = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      await CacheService.saveList(CacheService.keyFeaturedLandmarks, rawList);

      return (
        landmarks: rawList.map(Landmark.fromJson).toList(),
        fromCache: false,
      );
    } on DioException {
      final cached = await CacheService.loadList(CacheService.keyFeaturedLandmarks);
      if (cached != null) {
        return (landmarks: cached.map(Landmark.fromJson).toList(), fromCache: true);
      }
      rethrow;
    }
  }

  /// GET /api/v1/landmarks/{id}
  Future<({Landmark landmark, bool fromCache})> fetchById(int id) async {
    try {
      final response = await _dio.get('/landmarks/$id');
      final data = response.data as Map<String, dynamic>;
      final raw = data['data'] as Map<String, dynamic>;

      await CacheService.saveMap(CacheService.landmarkDetailKey(id), raw);

      return (landmark: Landmark.fromJson(raw), fromCache: false);
    } on DioException {
      final cached = await CacheService.loadMap(CacheService.landmarkDetailKey(id));
      if (cached != null) {
        return (landmark: Landmark.fromJson(cached), fromCache: true);
      }
      rethrow;
    }
  }

  /// POST /api/v1/landmarks/{id}/visit
  /// Fire-and-forget — logs an AR view for the Reports page.
  /// Errors are silently swallowed so a network issue never blocks the AR launch.
  Future<void> logVisit(int landmarkId) async {
    try {
      await _dio.post('/landmarks/$landmarkId/visit');
    } catch (_) {
      // Non-critical — ignore failures silently
    }
  }
}
