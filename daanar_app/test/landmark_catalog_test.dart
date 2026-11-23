import 'package:daanar_app/models/landmark.dart';
import 'package:daanar_app/providers/landmark_providers.dart';
import 'package:daanar_app/services/landmark_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> landmarkJson(int id, String category, String town) => {
  'id': id,
  'name': 'Landmark $id',
  'category': category,
  'location': {'lat': 16, 'lng': 120},
  'municipality': {
    'id': 1,
    'name': town,
    'province': 'Pangasinan',
    'location': {'lat': 16, 'lng': 120},
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all pages are cached and offline filters use the complete list',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <int>[];
      var failPage = 0;
      final dio = Dio();
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = options.queryParameters['page'] as int;
            requests.add(page);
            if (page == failPage) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: <String, dynamic>{
                  'data': page == 1
                      ? [landmarkJson(101, 'park', 'Dagupan City')]
                      : [
                          landmarkJson(102, 'church', 'Dagupan City'),
                          landmarkJson(103, 'church', 'Manaoag'),
                        ],
                  'meta': <String, dynamic>{'last_page': 2, 'total': 3},
                },
              ),
            );
          },
        ),
      );
      final service = LandmarkService(dio);
      final online = await service.fetchAll();
      expect(online.landmarks.map((landmark) => landmark.id), [101, 102, 103]);
      expect(online.fromCache, isFalse);

      // Losing the connection during page 2 still gives the complete snapshot.
      failPage = 2;
      final container = ProviderContainer(
        overrides: [landmarkServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final filter = container.read(landmarkFilterProvider.notifier);
      filter.setCategory('church');
      final churches = await container.read(filteredLandmarksProvider.future);
      expect(churches.fromCache, isTrue);
      expect(churches.catalogTotal, 3);
      expect(churches.landmarks.map((landmark) => landmark.id), [102, 103]);

      filter.setMunicipality('dagupan');
      final dagupan = await container.read(filteredLandmarksProvider.future);
      expect(dagupan.landmarks.single.id, 102);
      expect(requests, [1, 2, 1, 2]);
    },
  );

  test('3D availability requires a model URL or bundled asset', () {
    final remote = landmarkJson(101, 'park', 'Dagupan City');
    expect(Landmark.fromJson(remote).isArReady, isFalse);
    remote['media'] = {'ar_model_url': 'https://example.com/landmark.glb'};
    expect(Landmark.fromJson(remote).isArReady, isTrue);
    expect(
      Landmark.fromJson(landmarkJson(7, 'park', 'Dagupan City')).isArReady,
      isTrue,
    );
  });
}
