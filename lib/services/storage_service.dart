import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plant.dart';
import 'analytics_service.dart';

class StorageService {
  static const String _plantsKey = 'plants';

  Future<List<Plant>> loadPlants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_plantsKey);
      if (json == null || json.isEmpty) return [];
      final appDir = await getApplicationDocumentsDirectory();
      final plants = Plant.listFromJson(json);
      return plants.map((p) => _withAbsolutePaths(p, appDir.path)).toList();
    } catch (e, stack) {
      AnalyticsService.recordError(e, stack);
      return [];
    }
  }

  Future<void> savePlants(List<Plant> plants) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appDir = await getApplicationDocumentsDirectory();
      final toSave =
          plants.map((p) => _withRelativePaths(p, appDir.path)).toList();
      await prefs.setString(_plantsKey, Plant.listToJson(toSave));
    } catch (e, stack) {
      AnalyticsService.recordError(e, stack);
      rethrow;
    }
  }

  Future<String> copyImageToPermanentStorage(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final plantsDir = Directory('${appDir.path}/plants');
    if (!await plantsDir.exists()) {
      await plantsDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final relativePath = 'plants/$fileName';
    await File(tempPath).copy('${appDir.path}/$relativePath');
    return relativePath;
  }

  Future<void> deleteAllImages(Plant plant) async {
    for (final path in plant.imagePaths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> deleteImageFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  // ── path helpers ──────────────────────────────────────────────────────────

  Plant _withAbsolutePaths(Plant plant, String docsPath) {
    final sightings = plant.sightings
        .map((s) => s.copyWith(imagePath: _toAbsolute(s.imagePath, docsPath)))
        .toList();
    return plant.copyWith(sightings: sightings);
  }

  Plant _withRelativePaths(Plant plant, String docsPath) {
    final sightings = plant.sightings
        .map((s) => s.copyWith(imagePath: _toRelative(s.imagePath, docsPath)))
        .toList();
    return plant.copyWith(sightings: sightings);
  }

  String _toAbsolute(String path, String docsPath) {
    if (path.startsWith('/')) return path; // legacy absolute path, use as-is
    return '$docsPath/$path';
  }

  String _toRelative(String path, String docsPath) {
    if (!path.startsWith('/')) return path; // already relative
    if (path.startsWith(docsPath)) {
      final rel = path.substring(docsPath.length);
      return rel.startsWith('/') ? rel.substring(1) : rel;
    }
    // Different container UUID — extract the 'plants/filename.jpg' portion
    final idx = path.indexOf('/plants/');
    if (idx != -1) return path.substring(idx + 1);
    return path;
  }
}
