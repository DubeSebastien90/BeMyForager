import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/plant.dart';
import '../models/sighting.dart';
import 'storage_service.dart';

class DemoDataService {
  static const _uuid = Uuid();
  final _storage = StorageService();

  Future<void> populate() async {
    final now = DateTime.now();
    final appDir = await getApplicationDocumentsDirectory();
    final plantsDir = Directory('${appDir.path}/plants');
    if (!await plantsDir.exists()) await plantsDir.create(recursive: true);

    final newPlants = <Plant>[];

    for (final spec in _specs) {
      assert(spec.assetPaths.length == spec.sightings.length,
          '${spec.scientificName}: assetPaths and sightings must have the same length');

      final sightings = <Sighting>[];
      for (var i = 0; i < spec.sightings.length; i++) {
        final s = spec.sightings[i];
        final path = await _copyAsset(spec.assetPaths[i], plantsDir.path);
        sightings.add(Sighting(
          imagePath: path,
          capturedAt: now.subtract(Duration(days: s.daysAgo)),
          latitude: s.lat,
          longitude: s.lon,
          country: s.country,
          administrativeArea: s.area,
          locality: s.locality,
          subLocality: s.subLocality,
          placeName: s.placeName,
        ));
      }

      final oldestDaysAgo =
          spec.sightings.map((s) => s.daysAgo).reduce((a, b) => a > b ? a : b);
      newPlants.add(Plant(
        id: _uuid.v4(),
        sightings: sightings,
        scientificName: spec.scientificName,
        commonName: spec.commonName,
        family: spec.family,
        confidence: spec.confidence,
        tags: spec.tags,
        createdAt: now.subtract(Duration(days: oldestDaysAgo)),
      ));
    }

    final existing = await _storage.loadPlants();
    await _storage.savePlants([...existing, ...newPlants]);
  }

  static Future<String> _copyAsset(String assetPath, String dir) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final ext = assetPath.split('.').last;
    final name = 'demo_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.$ext';
    final path = '$dir/$name';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  // ── Demo plant catalogue ───────────────────────────────────────────────────

  static const _specs = [
    // Common Dandelion — two stages: bloom then seed head
    _PlantSpec(
      commonName: 'Common Dandelion',
      scientificName: 'Taraxacum officinale',
      family: 'Asteraceae',
      confidence: 0.97,
      tags: ['Edible', 'Herb', 'Flower'],
      assetPaths: [
        'assets/demo/dandelion_1.jpg',
        'assets/demo/dandelion_2.jpg',
      ],
      sightings: [
        _SightingSpec(20, 45.509, -73.588, 'Canada', 'Québec', 'Montréal',
            placeName: 'Parc du Mont-Royal'),
        _SightingSpec(55, 45.560, -73.559, 'Canada', 'Québec', 'Montréal',
            placeName: 'Jardin botanique de Montréal'),
      ],
    ),

    // Sugar Maple — fall foliage, two sightings in Québec
    _PlantSpec(
      commonName: 'Sugar Maple',
      scientificName: 'Acer saccharum',
      family: 'Sapindaceae',
      confidence: 0.89,
      tags: ['Tree'],
      assetPaths: [
        'assets/demo/maple_tree_1.jpg',
        'assets/demo/maple_tree_2.jpg',
      ],
      sightings: [
        _SightingSpec(245, 45.375, -72.732, 'Canada', 'Québec', 'Granby',
            placeName: 'Parc de la Yamaska'),
        _SightingSpec(250, 45.321, -72.225, 'Canada', 'Québec', 'Orford',
            placeName: 'Parc national du Mont-Orford'),
      ],
    ),

    // Tomato — garden with ripe fruits
    _PlantSpec(
      commonName: 'Tomato',
      scientificName: 'Solanum lycopersicum',
      family: 'Solanaceae',
      confidence: 0.95,
      tags: ['Edible', 'Herb', 'Flower'],
      assetPaths: ['assets/demo/tomato_plant.jpg'],
      sightings: [
        _SightingSpec(35, 45.535, -73.605, 'Canada', 'Québec', 'Montréal',
            subLocality: 'Rosemont–La Petite-Patrie'),
      ],
    ),

    // Common Lilac — purple flower clusters
    _PlantSpec(
      commonName: 'Common Lilac',
      scientificName: 'Syringa vulgaris',
      family: 'Oleaceae',
      confidence: 0.93,
      tags: ['Shrub', 'Flower'],
      assetPaths: ['assets/demo/lilac.jpg'],
      sightings: [
        _SightingSpec(42, 45.559, -73.546, 'Canada', 'Québec', 'Montréal',
            placeName: 'Parc Maisonneuve'),
      ],
    ),

    // Saguaro — iconic columnar desert cactus
    _PlantSpec(
      commonName: 'Saguaro',
      scientificName: 'Carnegiea gigantea',
      family: 'Cactaceae',
      confidence: 0.91,
      tags: ['Tree', 'Flower'],
      assetPaths: ['assets/demo/cactus.jpg'],
      sightings: [
        _SightingSpec(180, 32.178, -111.069, 'United States', 'Arizona',
            'Tucson',
            placeName: 'Saguaro National Park'),
      ],
    ),
  ];
}

// ── Private spec types ────────────────────────────────────────────────────────

class _PlantSpec {
  final String commonName, scientificName, family;
  final double confidence;
  final List<String> tags;
  final List<String> assetPaths;
  final List<_SightingSpec> sightings;

  const _PlantSpec({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.confidence,
    required this.tags,
    required this.assetPaths,
    required this.sightings,
  });
}

class _SightingSpec {
  final int daysAgo;
  final double lat, lon;
  final String country, area, locality;
  final String? subLocality, placeName;

  const _SightingSpec(
    this.daysAgo,
    this.lat,
    this.lon,
    this.country,
    this.area,
    this.locality, {
    this.subLocality,
    this.placeName,
  });
}
