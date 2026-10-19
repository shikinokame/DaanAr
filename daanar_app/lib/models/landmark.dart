import 'municipality.dart';

class LandmarkMedia {
  final String? heroImage;
  final String? arMarkerImage;
  final String? arModelUrl;
  final String? arHtmlPath;

  const LandmarkMedia({
    this.heroImage,
    this.arMarkerImage,
    this.arModelUrl,
    this.arHtmlPath,
  });

  factory LandmarkMedia.fromJson(Map<String, dynamic> json) => LandmarkMedia(
        heroImage: json['hero_image'] as String?,
        arMarkerImage: json['ar_marker_image'] as String?,
        arModelUrl: json['ar_model_url'] as String?,
        arHtmlPath: json['ar_html_path'] as String?,
      );
}

class Landmark {
  final int id;
  final String name;
  final String shortDescription;
  final String description;
  final String category;
  final String? era;
  final String address;
  final double lat;
  final double lng;
  final bool isFeatured;
  final LandmarkMedia media;
  final Municipality? municipality;

  const Landmark({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.category,
    this.era,
    required this.address,
    required this.lat,
    required this.lng,
    required this.isFeatured,
    required this.media,
    this.municipality,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final mediaJson = json['media'] as Map<String, dynamic>? ?? {};
    final municipalityJson = json['municipality'];

    return Landmark(
      id: json['id'] as int,
      name: json['name'] as String,
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      era: json['era'] as String?,
      address: json['address'] as String? ?? '',
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      isFeatured: json['is_featured'] as bool? ?? false,
      media: LandmarkMedia.fromJson(mediaJson),
      municipality: municipalityJson != null
          ? Municipality.fromJson(municipalityJson as Map<String, dynamic>)
          : null,
    );
  }

  /// Whether this landmark has an AR / 3D experience available.
  bool get isArReady =>
      (media.arModelUrl != null && media.arModelUrl!.isNotEmpty) ||
      (media.arHtmlPath != null && media.arHtmlPath!.isNotEmpty) ||
      id > 0;
}
