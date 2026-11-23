import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../core/token_storage.dart';
import '../models/landmark.dart';
import 'history_service.dart';

final landmarkServiceProvider = Provider<LandmarkService>(
  (ref) => LandmarkService(ref.read(apiClientProvider).dio),
);

class LandmarkService {
  final Dio _dio;
  const LandmarkService(this._dio);

  /// Fetch the entire catalog before replacing the last usable offline snapshot.
  Future<({List<Landmark> landmarks, bool fromCache, int? catalogTotal})>
  fetchAll() async {
    try {
      final recordsById = <int, Map<String, dynamic>>{};
      var lastPage = 1;
      int? total;
      for (var page = 1; page <= lastPage; page++) {
        final response = await _dio.get(
          '/landmarks',
          queryParameters: {'page': page},
        );
        final data = response.data as Map<String, dynamic>;
        if (page == 1) {
          final meta = data['meta'] as Map<String, dynamic>?;
          lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
          total = (meta?['total'] as num?)?.toInt();
        }
        for (final record
            in (data['data'] as List).cast<Map<String, dynamic>>()) {
          recordsById[record['id'] as int] = record;
        }
      }
      final records = recordsById.values.toList(growable: false);
      final landmarks = records.map(Landmark.fromJson).toList(growable: false);
      await CacheService.saveMap(CacheService.keyLandmarkCatalog, {
        'records': records,
        'total': total ?? landmarks.length,
      });
      return (
        landmarks: landmarks,
        fromCache: false,
        catalogTotal: total ?? landmarks.length,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) rethrow;
      final cached = await CacheService.loadLandmarkCatalog();
      if (cached == null) rethrow;
      return (
        landmarks: cached.records
            .map(Landmark.fromJson)
            .toList(growable: false),
        fromCache: true,
        catalogTotal: cached.total,
      );
    }
  }

  /// GET /api/v1/landmarks/featured
  Future<({List<Landmark> landmarks, bool fromCache})> fetchFeatured() async {
    try {
      final response = await _dio.get('/landmarks/featured');
      final data = response.data as Map<String, dynamic>;
      final rawList = (data['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      await CacheService.saveList(CacheService.keyFeaturedLandmarks, rawList);

      return (
        landmarks: rawList.map(Landmark.fromJson).toList(),
        fromCache: false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) rethrow;
      final cached = await CacheService.loadList(
        CacheService.keyFeaturedLandmarks,
      );
      if (cached != null) {
        return (
          landmarks: cached.map(Landmark.fromJson).toList(),
          fromCache: true,
        );
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) rethrow;
      final cached = await CacheService.loadMap(
        CacheService.landmarkDetailKey(id),
      );
      if (cached != null) {
        return (landmark: Landmark.fromJson(cached), fromCache: true);
      }
      rethrow;
    }
  }

  /// POST /api/v1/analytics/log-event
  /// Logs a split analytics event tied to the authenticated mobile user (`userId`).
  /// Supported `actionType` values:
  /// - `'PHYSICAL_VISIT'` (On-site GPS geofence <= 100m or QR marker)
  /// - `'AR_VIEW'` (Virtual 3D/AR model view)
  /// - `'MAP_NAV'` (Route navigation started)
  /// - `'PAGE_VIEW'` (Landmark details screen opened)
  Future<void> logAnalyticsEvent({
    required int landmarkId,
    required String actionType,
    String? verificationMethod,
    double? userLat,
    double? userLng,
    Landmark? landmark,
  }) async {
    // Record locally into User Visit & AR Viewing History right away
    try {
      await HistoryService.instance.recordFromAnalytics(
        landmarkId: landmarkId,
        actionType: actionType,
        verificationMethod: verificationMethod,
        landmark: landmark,
      );
    } catch (_) {}

    try {
      final userId = await TokenStorage.getUserId();
      final phone = await TokenStorage.getPhoneNumber();
      final payload = <String, dynamic>{
        'userId': userId,
        'landmarkId': landmarkId,
        'actionType': actionType,
        'verificationMethod':
            verificationMethod ??
            (actionType == 'PHYSICAL_VISIT' ? 'GPS_GEOFENCE' : 'REMOTE'),
        'userLat': ?userLat,
        'userLng': ?userLng,
        'deviceId': userId != null ? 'user_$userId' : phone,
      };

      try {
        await _dio.post('/analytics/log-event', data: payload);
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) return;
        // Fallback to legacy visit endpoint if running against an older server build
        await _dio.post('/landmarks/$landmarkId/visit', data: payload);
      }
    } catch (_) {
      // Non-critical never block UI interaction on analytics network failure
    }
  }

  /// Backwards-compatible alias for logging an AR view.
  Future<void> logVisit(int landmarkId) => logAnalyticsEvent(
    landmarkId: landmarkId,
    actionType: 'AR_VIEW',
    verificationMethod: 'REMOTE',
  );
}
