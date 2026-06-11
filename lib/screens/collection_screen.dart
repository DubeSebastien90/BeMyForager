import 'dart:io';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sighting.dart';
import '../services/storage_service.dart';
import '../widgets/plant_card.dart';
import 'location_group_screen.dart';
import 'plant_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _storage = StorageService();
  final _searchController = TextEditingController();

  List<Plant> _plants = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final plants = await _storage.loadPlants();
    setState(() {
      _plants = plants.reversed.toList();
      _loading = false;
    });
  }

  Future<void> _openDetail(Plant plant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => PlantDetailScreen(plant: plant)),
    );
    _load();
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
    setState(() => _plants = updated.reversed.toList());
  }

  // ── location groups ───────────────────────────────────────────────────────

  /// Map of locationGroupKey → list of plants with at least one sighting there.
  /// Sorted alphabetically. Returns null when no plant has location data.
  Map<String, List<Plant>>? get _locationGroups {
    final map = <String, List<Plant>>{};
    for (final plant in _plants) {
      final keys = plant.sightings
          .map((s) => s.locationGroupKey)
          .where((k) => k != 'Unknown location')
          .toSet();
      for (final key in keys) {
        map.putIfAbsent(key, () => []);
        if (!map[key]!.any((p) => p.id == plant.id)) map[key]!.add(plant);
      }
    }
    if (map.isEmpty) return null;
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// First sighting image from [locationKey] across all plants in that group.
  String _representativeImage(String locationKey, List<Plant> plants) {
    for (final plant in plants) {
      for (final s in plant.sightings) {
        if (s.locationGroupKey == locationKey) return s.imagePath;
      }
    }
    return plants.first.mainImagePath;
  }

  // ── search ────────────────────────────────────────────────────────────────

  /// Returns filtered plants + the matching sighting image (or null = main photo).
  List<({Plant plant, String? overrideImage})> get _searchResults {
    final q = _query.toLowerCase();
    final result = <({Plant plant, String? overrideImage})>[];
    for (final plant in _plants) {
      final nameMatch = plant.commonName.toLowerCase().contains(q) ||
          plant.scientificName.toLowerCase().contains(q) ||
          plant.family.toLowerCase().contains(q);

      Sighting? matchingSighting;
      for (final s in plant.sightings) {
        if (s.matchesQuery(q)) {
          matchingSighting = s;
          break;
        }
      }

      if (nameMatch || matchingSighting != null) {
        result.add((
          plant: plant,
          overrideImage: matchingSighting?.imagePath,
        ));
      }
    }
    return result;
  }

  // ── grid delegate ─────────────────────────────────────────────────────────

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.72,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  );

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // ── search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name, family, location…',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green[300]!, width: 1.5),
              ),
            ),
          ),
        ),

        // ── content ─────────────────────────────────────────────────────────
        Expanded(
          child: _query.isNotEmpty ? _buildSearchResults() : _buildDefault(),
        ),
      ],
    );
  }

  // ── search results ────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No results for "$_query"',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: _gridDelegate,
      itemCount: results.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => _openDetail(results[i].plant),
        onLongPress: () => _confirmDelete(results[i].plant),
        child: PlantCard(
          plant: results[i].plant,
          overrideImagePath: results[i].overrideImage,
        ),
      ),
    );
  }

  // ── default view ──────────────────────────────────────────────────────────

  Widget _buildDefault() {
    if (_plants.isEmpty) return _emptyState();

    final groups = _locationGroups;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // ── location groups strip ────────────────────────────────────────
          if (groups != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[600], size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Locations',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 118,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: groups.length,
                  itemBuilder: (ctx, i) {
                    final key = groups.keys.elementAt(i);
                    final plants = groups[key]!;
                    return _LocationGroupCard(
                      locationKey: key,
                      plantCount: plants.length,
                      imagePath: _representativeImage(key, plants),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationGroupScreen(
                            locationKey: key,
                            plants: plants,
                          ),
                        ),
                      ).then((_) => _load()),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],

          // ── My Plants section header ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.eco, color: Colors.green[600], size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'My Plants',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_plants.length})',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),

          // ── plants grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => GestureDetector(
                  onTap: () => _openDetail(_plants[i]),
                  onLongPress: () => _confirmDelete(_plants[i]),
                  child: PlantCard(plant: _plants[i]),
                ),
                childCount: _plants.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.eco_outlined, size: 80, color: Colors.green[200]),
          const SizedBox(height: 16),
          Text(
            'No plants yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Identify to snap your first plant!',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── Location group card ───────────────────────────────────────────────────────

class _LocationGroupCard extends StatelessWidget {
  final String locationKey;
  final int plantCount;
  final String imagePath;
  final VoidCallback onTap;

  const _LocationGroupCard({
    required this.locationKey,
    required this.plantCount,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => ColoredBox(
                  color: Colors.green[100]!,
                  child: const Center(
                    child: Icon(Icons.image_outlined,
                        color: Colors.white54, size: 36),
                  ),
                ),
              ),
              // gradient overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              // label
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            locationKey,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$plantCount plant${plantCount > 1 ? "s" : ""}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
