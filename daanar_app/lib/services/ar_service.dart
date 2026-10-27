import '../core/constants.dart';
import '../models/landmark.dart';

/// Helper service that determines AR availability for a landmark.
class ARService {
  ARService._();

  /// Returns true if the landmark has both a marker image and a 3D model.
  /// Both are required for the full NFT AR experience.
  static bool isARAvailable(Landmark landmark) {
    return landmark.media.arMarkerImage != null &&
        landmark.media.arModelUrl != null;
  }

  /// Returns true if the landmark has a 3D model, marker image, or bundled offline model.
  static bool hasAnyARAsset(Landmark landmark) {
    return landmark.media.arMarkerImage != null ||
        landmark.media.arModelUrl != null ||
        const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}.contains(landmark.id);
  }

  /// Builds the URL for the WebAR page served by Laravel.
  /// [demo] forces demo/HIRO mode regardless of server-side check.
  static String buildARUrl(int landmarkId, {bool demo = false}) {
    // Strip /api/v1 suffix to get the base server URL
    final base = AppConstants.baseUrl
        .replaceFirst('/api/v1', '')
        .replaceFirst(RegExp(r'/$'), '');

    final url = '$base/ar/landmark/$landmarkId';
    return demo ? '$url?demo=1' : url;
  }

  /// URL for the standalone camera+A-Frame test page.
  static String get testUrl {
    final base = AppConstants.baseUrl
        .replaceFirst('/api/v1', '')
        .replaceFirst(RegExp(r'/$'), '');
    return '$base/ar/test';
  }
}
