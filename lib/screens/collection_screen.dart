import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sighting.dart';
import '../services/storage_service.dart';
import '../widgets/plant_card.dart' show PlantCard, tagColor, localizedTag;
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
  String? _selectedTag;

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
        title: Text('remove_plant_title'.tr()),
        content: Text(
            'remove_plant_content'.tr(namedArgs: {'name': plant.commonName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('remove'.tr()),
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

  // ── tag filter ────────────────────────────────────────────────────────────

  static const _tagOrder = [
    'Edible', 'Medicinal', 'Toxic',
    'Tree', 'Shrub', 'Herb', 'Grass', 'Flower', 'Vine', 'Fern', 'Mushroom',
  ];

  /// All unique tags across every plant, in canonical order.
  List<String> get _allTags {
    final present = _plants.expand((p) => p.tags).toSet();
    return _tagOrder.where(present.contains).toList();
  }

  /// Plants filtered by the active tag (ignored during search).
  List<Plant> get _tagFilteredPlants => _selectedTag == null
      ? _plants
      : _plants.where((p) => p.tags.contains(_selectedTag)).toList();

  /// Representative image for a tag — first plant with that tag.
  String _representativeTagImage(String tag) {
    for (final plant in _plants) {
      if (plant.tags.contains(tag)) return plant.mainImagePath;
    }
    return '';
  }

  // ── location groups ───────────────────────────────────────────────────────

  Map<String, List<Plant>>? get _locationGroups {
    final map = <String, List<Plant>>{};
    for (final plant in _tagFilteredPlants) {
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

  String _representativeImage(String locationKey, List<Plant> plants) {
    for (final plant in plants) {
      for (final s in plant.sightings) {
        if (s.locationGroupKey == locationKey) return s.imagePath;
      }
    }
    return plants.first.mainImagePath;
  }

  // ── search ────────────────────────────────────────────────────────────────

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
              hintText: 'search_hint'.tr(),
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
              'no_results'.tr(namedArgs: {'query': _query}),
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
    final plants = _tagFilteredPlants;
    if (_plants.isEmpty) return _emptyState();

    final tags = _allTags;
    final groups = _locationGroups;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          // ── category strip ───────────────────────────────────────────────
          if (tags.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.label_outline,
                        color: Colors.green[600], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'category'.tr(),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (_selectedTag != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedTag = null),
                        child: Text(
                          'clear'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
                  itemCount: tags.length,
                  itemBuilder: (ctx, i) {
                    final tag = tags[i];
                    final count = _plants
                        .where((p) => p.tags.contains(tag))
                        .length;
                    return _CategoryCard(
                      tag: tag,
                      plantCount: count,
                      imagePath: _representativeTagImage(tag),
                      selected: _selectedTag == tag,
                      onTap: () => setState(() =>
                          _selectedTag = _selectedTag == tag ? null : tag),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
          ],

          // ── location groups strip ────────────────────────────────────────
          if (groups != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.green[600], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'locations'.tr(),
                      style: const TextStyle(
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
                    final groupPlants = groups[key]!;
                    return _LocationGroupCard(
                      locationKey: key,
                      plantCount: groupPlants.length,
                      imagePath: _representativeImage(key, groupPlants),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationGroupScreen(
                            locationKey: key,
                            plants: groupPlants,
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
                  Text(
                    'my_plants'.tr(),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${plants.length})',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),

          // ── plants grid ──────────────────────────────────────────────────
          plants.isEmpty
              ? SliverFillRemaining(child: _noTagResults())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: _gridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => GestureDetector(
                        onTap: () => _openDetail(plants[i]),
                        onLongPress: () => _confirmDelete(plants[i]),
                        child: PlantCard(plant: plants[i]),
                      ),
                      childCount: plants.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _noTagResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_off_outlined, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'no_tag_plants'.tr(namedArgs: {
              'tag': localizedTag(_selectedTag!),
            }),
            style: TextStyle(color: Colors.grey[400], fontSize: 15),
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
            'no_plants_yet'.tr(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'no_plants_hint'.tr(),
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final String tag;
  final int plantCount;
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.tag,
    required this.plantCount,
    required this.imagePath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: color, width: 2.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 14 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // plant image background
              imagePath.isNotEmpty
                  ? Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => ColoredBox(
                        color: color.withValues(alpha: 0.15),
                      ),
                    )
                  : ColoredBox(color: color.withValues(alpha: 0.15)),

              // gradient overlay
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),

              // colored top-left accent strip
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    localizedTag(tag),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // selected checkmark
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 10),
                  ),
                ),

              // bottom label
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  'plant_count'.plural(plantCount),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
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
                      'plant_count'.plural(plantCount),
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
