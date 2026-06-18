class Sighting {
  final String imagePath;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? country;
  final String? administrativeArea;
  final String? locality;
  final String? subLocality;
  /// Specific POI / park / forest name from the OS geocoder.
  final String? placeName;
  final double? confidence;

  const Sighting({
    required this.imagePath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.country,
    this.administrativeArea,
    this.locality,
    this.subLocality,
    this.placeName,
    this.confidence,
  });

  String? get locationLabel {
    if (placeName != null) return placeName;
    if (subLocality != null && locality != null) return '$subLocality, $locality';
    if (locality != null) return locality;
    if (administrativeArea != null) return administrativeArea;
    if (country != null) return country;
    return null;
  }

  /// Grouping key: specific place (park/POI) → district → city → province → country.
  /// A place name that starts with a digit is treated as a street address and skipped.
  String get locationGroupKey {
    final p = placeName;
    if (p != null && p.isNotEmpty && !RegExp(r'^\d').hasMatch(p)) return p;
    return subLocality ?? locality ?? administrativeArea ?? country ?? 'Unknown location';
  }

  bool matchesQuery(String q) =>
      (placeName?.toLowerCase().contains(q) ?? false) ||
      (locality?.toLowerCase().contains(q) ?? false) ||
      (subLocality?.toLowerCase().contains(q) ?? false) ||
      (administrativeArea?.toLowerCase().contains(q) ?? false) ||
      (country?.toLowerCase().contains(q) ?? false);

  String fullLocationString() {
    final parts = <String>[];
    if (placeName != null) parts.add(placeName!);
    if (subLocality != null && subLocality != placeName) parts.add(subLocality!);
    if (locality != null) parts.add(locality!);
    if (administrativeArea != null && locality == null) {
      parts.add(administrativeArea!);
    }
    if (country != null) parts.add(country!);
    return parts.join(', ');
  }

  Sighting copyWith({String? imagePath}) => Sighting(
    imagePath: imagePath ?? this.imagePath,
    capturedAt: capturedAt,
    latitude: latitude,
    longitude: longitude,
    country: country,
    administrativeArea: administrativeArea,
    locality: locality,
    subLocality: subLocality,
    placeName: placeName,
    confidence: confidence,
  );

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'capturedAt': capturedAt.toIso8601String(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (country != null) 'country': country,
    if (administrativeArea != null) 'administrativeArea': administrativeArea,
    if (locality != null) 'locality': locality,
    if (subLocality != null) 'subLocality': subLocality,
    if (placeName != null) 'placeName': placeName,
    if (confidence != null) 'confidence': confidence,
  };

  factory Sighting.fromJson(Map<String, dynamic> json) => Sighting(
    imagePath: json['imagePath'] as String,
    capturedAt: DateTime.parse(json['capturedAt'] as String),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    country: json['country'] as String?,
    administrativeArea: json['administrativeArea'] as String?,
    locality: json['locality'] as String?,
    subLocality: json['subLocality'] as String?,
    placeName: json['placeName'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}
