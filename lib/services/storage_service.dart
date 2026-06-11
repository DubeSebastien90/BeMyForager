import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plant.dart';

class StorageService {
  static const String _plantsKey = 'plants';

  Future<List<Plant>> loadPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_plantsKey);
    if (json == null || json.isEmpty) return [];
    return Plant.listFromJson(json);
  }

  Future<void> savePlants(List<Plant> plants) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plantsKey, Plant.listToJson(plants));
  }

  Future<String> copyImageToPermanentStorage(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final plantsDir = Directory('${appDir.path}/plants');
    if (!await plantsDir.exists()) {
      await plantsDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = '${plantsDir.path}/$fileName';
    await File(tempPath).copy(dest);
    return dest;
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
}
