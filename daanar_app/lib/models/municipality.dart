class Municipality {
  final int id;
  final String name;
  final String province;
  final double lat;
  final double lng;
  final String? description;
  final int? landmarksCount;

  const Municipality({
    required this.id,
    required this.name,
    required this.province,
    required this.lat,
    required this.lng,
    this.description,
    this.landmarksCount,
  });

  factory Municipality.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    return Municipality(
      id: json['id'] as int,
      name: json['name'] as String,
      province: json['province'] as String,
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      description: json['description'] as String?,
      landmarksCount: json['landmarks_count'] as int?,
    );
  }
}
