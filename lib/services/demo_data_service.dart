import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
      final sightings = <Sighting>[];
      for (final s in spec.sightings) {
        final path = await _makePlaceholderImage(plantsDir.path, spec.color);
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
        createdAt: now.subtract(Duration(days: oldestDaysAgo)),
      ));
    }

    final existing = await _storage.loadPlants();
    await _storage.savePlants([...existing, ...newPlants]);
  }

  static Future<String> _makePlaceholderImage(String dir, Color base) async {
    const w = 480;
    const h = 360;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Gradient background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          ui.Offset(w.toDouble(), h.toDouble()),
          [base, Color.lerp(base, Colors.white, 0.50)!],
        ),
    );

    final accent = Color.lerp(base, Colors.black, 0.30)!;

    // Leaf body
    canvas.drawOval(
      ui.Rect.fromCenter(
          center: ui.Offset(w / 2, h / 2 - 10), width: 130, height: 190),
      ui.Paint()..color = accent,
    );

    // Stem
    canvas.drawLine(
      ui.Offset(w / 2, h / 2 + 85),
      ui.Offset(w / 2, h / 2 + 145),
      ui.Paint()
        ..color = accent
        ..strokeWidth = 7
        ..strokeCap = ui.StrokeCap.round,
    );

    // Centre vein
    canvas.drawLine(
      ui.Offset(w / 2, h / 2 - 105),
      ui.Offset(w / 2, h / 2 + 85),
      ui.Paint()
        ..color = Color.lerp(accent, Colors.white, 0.45)!
        ..strokeWidth = 2.5,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final path =
        '$dir/demo_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.png';
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    return path;
  }

  // ── Demo plant catalogue ───────────────────────────────────────────────────

  static const _specs = [
    _PlantSpec(
      commonName: 'Wild Blackberry',
      scientificName: 'Rubus fruticosus',
      family: 'Rosaceae',
      confidence: 0.94,
      color: Color(0xFF6A1B9A),
      sightings: [
        _SightingSpec(70, 48.401, 2.702, 'France', 'Île-de-France',
            'Fontainebleau',
            placeName: 'Forêt de Fontainebleau'),
        _SightingSpec(35, 48.835, 2.440, 'France', 'Île-de-France',
            'Vincennes',
            subLocality: 'Bois de Vincennes'),
      ],
    ),
    _PlantSpec(
      commonName: 'Common Dandelion',
      scientificName: 'Taraxacum officinale',
      family: 'Asteraceae',
      confidence: 0.98,
      color: Color(0xFFF9A825),
      sightings: [
        _SightingSpec(55, 45.508, -73.587, 'Canada', 'Québec', 'Montréal',
            placeName: 'Parc du Mont-Royal'),
        _SightingSpec(20, 45.536, -73.615, 'Canada', 'Québec', 'Montréal',
            subLocality: 'Rosemont'),
      ],
    ),
    _PlantSpec(
      commonName: 'Wild Garlic',
      scientificName: 'Allium ursinum',
      family: 'Amaryllidaceae',
      confidence: 0.91,
      color: Color(0xFF2E7D32),
      sightings: [
        _SightingSpec(45, 51.557, -0.178, 'United Kingdom', 'England',
            'London',
            placeName: 'Hampstead Heath'),
        _SightingSpec(60, 51.442, -0.291, 'United Kingdom', 'England',
            'London',
            placeName: 'Richmond Park'),
        _SightingSpec(25, 51.511, -0.138, 'United Kingdom', 'England',
            'London',
            subLocality: 'Covent Garden'),
      ],
    ),
    _PlantSpec(
      commonName: 'Stinging Nettle',
      scientificName: 'Urtica dioica',
      family: 'Urticaceae',
      confidence: 0.97,
      color: Color(0xFF388E3C),
      sightings: [
        _SightingSpec(15, 48.886, 2.343, 'France', 'Île-de-France', 'Paris',
            subLocality: 'Montmartre'),
        _SightingSpec(80, 48.846, 2.337, 'France', 'Île-de-France', 'Paris',
            placeName: 'Jardin du Luxembourg'),
      ],
    ),
    _PlantSpec(
      commonName: 'European Elder',
      scientificName: 'Sambucus nigra',
      family: 'Adoxaceae',
      confidence: 0.89,
      color: Color(0xFF558B2F),
      sightings: [
        _SightingSpec(25, 48.878, 2.381, 'France', 'Île-de-France', 'Paris',
            placeName: 'Parc des Buttes-Chaumont'),
        _SightingSpec(42, 45.523, -73.569, 'Canada', 'Québec', 'Montréal',
            subLocality: 'Plateau-Mont-Royal'),
      ],
    ),
  ];
}

// ── Private spec types ────────────────────────────────────────────────────────

class _PlantSpec {
  final String commonName, scientificName, family;
  final double confidence;
  final Color color;
  final List<_SightingSpec> sightings;

  const _PlantSpec({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.confidence,
    required this.color,
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
