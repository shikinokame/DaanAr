import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../models/trail.dart';

final trailServiceProvider = Provider<TrailService>(
  (ref) => TrailService(ref.read(apiClientProvider).dio),
);

class TrailService {
  final Dio _dio;
  const TrailService(this._dio);

  /// GET /api/v1/trails
  /// Caches on success; falls back to cache on network failure.
  Future<({List<Trail> trails, bool fromCache})> fetchAll() async {
    try {
      final response = await _dio.get('/trails');
      final data = response.data as Map<String, dynamic>;
      final rawList = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      await CacheService.saveList(CacheService.keyTrails, rawList);

      return (
        trails: rawList.map(Trail.fromJson).toList(),
        fromCache: false,
      );
    } on DioException {
      final cached = await CacheService.loadList(CacheService.keyTrails);
      if (cached != null) {
        return (trails: cached.map(Trail.fromJson).toList(), fromCache: true);
      }
      rethrow;
    }
  }

  /// GET /api/v1/trails/{id}
  Future<({Trail trail, bool fromCache})> fetchById(int id) async {
    try {
      final response = await _dio.get('/trails/$id');
      final data = response.data as Map<String, dynamic>;
      final raw = data['data'] as Map<String, dynamic>;

      await CacheService.saveMap(CacheService.trailDetailKey(id), raw);

      return (trail: Trail.fromJson(raw), fromCache: false);
    } on DioException {
      final cached = await CacheService.loadMap(CacheService.trailDetailKey(id));
      if (cached != null) {
        return (trail: Trail.fromJson(cached), fromCache: true);
      }
      rethrow;
    }
  }
}
