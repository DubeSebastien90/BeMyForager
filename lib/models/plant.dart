import 'dart:convert';
import 'sighting.dart';

class Plant {
  final String id;
  final List<Sighting> sightings; // first = main photo
  final String scientificName;
  final String commonName;
  final String family;
  final double confidence;
  final DateTime createdAt;
  final List<String> referenceImageUrls;
  final List<String> tags;

  const Plant({
    required this.id,
    required this.sightings,
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.confidence,
    required this.createdAt,
    this.referenceImageUrls = const [],
    this.tags = const [],
  });

  // ── computed ──────────────────────────────────────────────────────────────

  String get mainImagePath => sightings.first.imagePath;

  /// Flat list of image paths — used by StorageService.deleteAllImages.
  List<String> get imagePaths => sightings.map((s) => s.imagePath).toList();

  String? get referenceImageUrl =>
      referenceImageUrls.isNotEmpty ? referenceImageUrls.first : null;

  /// Combined label across all unique locations in this plant's sightings.
  String? get locationLabel {
    final labels = sightings
        .map((s) => s.locationLabel)
        .whereType<String>()
        .toSet()
        .toList();
    return labels.isEmpty ? null : labels.join(' · ');
  }

  // ── copy ──────────────────────────────────────────────────────────────────

  Plant copyWith({List<Sighting>? sightings, List<String>? tags}) => Plant(
    id: id,
    sightings: sightings ?? this.sightings,
    scientificName: scientificName,
    commonName: commonName,
    family: family,
    confidence: confidence,
    createdAt: createdAt,
    referenceImageUrls: referenceImageUrls,
    tags: tags ?? this.tags,
  );

  // ── serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'sightings': sightings.map((s) => s.toJson()).toList(),
    'scientificName': scientificName,
    'commonName': commonName,
    'family': family,
    'confidence': confidence,
    'createdAt': createdAt.toIso8601String(),
    'referenceImageUrls': referenceImageUrls,
    'tags': tags,
  };

  factory Plant.fromJson(Map<String, dynamic> json) {
    List<Sighting> sightings;

    if (json.containsKey('sightings')) {
      sightings = (json['sightings'] as List<dynamic>)
          .map((e) => Sighting.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // migration: old records had imagePaths list + optional plant-level location
      List<String> paths;
      if (json.containsKey('imagePaths')) {
        paths = (json['imagePaths'] as List<dynamic>).cast<String>();
      } else {
        paths = [json['imagePath'] as String];
      }
      final createdAt = DateTime.parse(json['createdAt'] as String);
      sightings = paths
          .map((path) => Sighting(
                imagePath: path,
                capturedAt: createdAt,
                latitude: (json['latitude'] as num?)?.toDouble(),
                longitude: (json['longitude'] as num?)?.toDouble(),
                country: json['country'] as String?,
                administrativeArea: json['administrativeArea'] as String?,
                locality: json['locality'] as String?,
                subLocality: json['subLocality'] as String?,
              ))
          .toList();
    }

    // migration: old single referenceImageUrl → list
    List<String> refUrls;
    if (json.containsKey('referenceImageUrls')) {
      refUrls = (json['referenceImageUrls'] as List<dynamic>).cast<String>();
    } else if (json['referenceImageUrl'] != null) {
      refUrls = [json['referenceImageUrl'] as String];
    } else {
      refUrls = const [];
    }

    return Plant(
      id: json['id'] as String,
      sightings: sightings,
      scientificName: json['scientificName'] as String,
      commonName: json['commonName'] as String,
      family: json['family'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      referenceImageUrls: refUrls,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  static List<Plant> listFromJson(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list.map((e) => Plant.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Plant> plants) =>
      jsonEncode(plants.map((p) => p.toJson()).toList());
}
