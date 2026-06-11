import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../services/storage_service.dart';
import '../widgets/plant_card.dart';
import 'plant_detail_screen.dart';

class LocationGroupScreen extends StatefulWidget {
  final String locationKey;
  final List<Plant> plants;

  const LocationGroupScreen({
    super.key,
    required this.locationKey,
    required this.plants,
  });

  @override
  State<LocationGroupScreen> createState() => _LocationGroupScreenState();
}

class _LocationGroupScreenState extends State<LocationGroupScreen> {
  final _storage = StorageService();
  late List<Plant> _plants;

  @override
  void initState() {
    super.initState();
    _plants = widget.plants;
  }

  /// For each plant, find the first sighting image from this location.
  String? _sightingImage(Plant plant) {
    for (final s in plant.sightings) {
      if (s.locationGroupKey == widget.locationKey) return s.imagePath;
    }
    return null;
  }

  Future<void> _openDetail(Plant plant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => PlantDetailScreen(plant: plant)),
    );
    // re-filter in case the plant was deleted
    final all = await _storage.loadPlants();
    setState(() {
      _plants = all
          .where((p) =>
              p.sightings.any((s) => s.locationGroupKey == widget.locationKey))
          .toList();
    });
    if (_plants.isEmpty && mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete(Plant plant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove plant?'),
        content: Text('Remove "${plant.commonName}" from your collection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _storage.deleteAllImages(plant);
    final all = await _storage.loadPlants();
    final updated = all.where((p) => p.id != plant.id).toList();
    await _storage.savePlants(updated);
    setState(() {
      _plants = updated
          .where((p) =>
              p.sightings.any((s) => s.locationGroupKey == widget.locationKey))
          .toList();
    });
    if (_plants.isEmpty && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.locationKey,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _plants.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _openDetail(_plants[i]),
          onLongPress: () => _confirmDelete(_plants[i]),
          child: PlantCard(
            plant: _plants[i],
            overrideImagePath: _sightingImage(_plants[i]),
          ),
        ),
      ),
    );
  }
}
