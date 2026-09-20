import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/cache_service.dart';
import '../models/municipality.dart';

final municipalityServiceProvider = Provider<MunicipalityService>(
  (ref) => MunicipalityService(ref.read(apiClientProvider).dio),
);

class MunicipalityService {
  final Dio _dio;
  const MunicipalityService(this._dio);

  /// GET /api/v1/municipalities
  /// Caches on success; falls back to cache on network failure.
  Future<({List<Municipality> municipalities, bool fromCache})> fetchAll() async {
    try {
      final response = await _dio.get('/municipalities');
      final data = response.data as Map<String, dynamic>;
      final rawList = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      await CacheService.saveList(CacheService.keyMunicipalities, rawList);

      return (
        municipalities: rawList.map(Municipality.fromJson).toList(),
        fromCache: false,
      );
    } on DioException {
      final cached = await CacheService.loadList(CacheService.keyMunicipalities);
      if (cached != null) {
        return (
          municipalities: cached.map(Municipality.fromJson).toList(),
          fromCache: true,
        );
      }
      rethrow;
    }
  }
}
