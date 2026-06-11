import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../models/sighting.dart';
import '../services/storage_service.dart';
import 'plant_reference_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final _storage = StorageService();
  late Plant _plant;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $h:$m';
  }


  Future<void> _persist(List<Sighting> sightings) async {
    final updated = _plant.copyWith(sightings: sightings);
    final all = await _storage.loadPlants();
    final idx = all.indexWhere((p) => p.id == _plant.id);
    if (idx != -1) {
      all[idx] = updated;
      await _storage.savePlants(all);
    }
    setState(() => _plant = updated);
  }

  Future<void> _setAsMain(int index) async {
    final sightings = List<Sighting>.from(_plant.sightings);
    final chosen = sightings.removeAt(index);
    sightings.insert(0, chosen);
    await _persist(sightings);
  }

  Future<void> _removePhoto(int index) async {
    await _storage.deleteImageFile(_plant.sightings[index].imagePath);
    final sightings = List<Sighting>.from(_plant.sightings)..removeAt(index);
    await _persist(sightings);
  }

  Future<void> _deletePlant() async {
    await _storage.deleteAllImages(_plant);
    final all = await _storage.loadPlants();
    await _storage.savePlants(all.where((p) => p.id != _plant.id).toList());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmRemoveLastPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text(
          'This is the only photo. Removing it will delete '
          '"${_plant.commonName}" from your collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete plant'),
          ),
        ],
      ),
    );
    if (confirm == true) await _deletePlant();
  }

  void _showOptions(int index) {
    final isMain = index == 0;
    final sighting = _plant.sightings[index];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // ── photo info ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateTime(sighting.capturedAt),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  if (sighting.locationLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sighting.fullLocationString(),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // ── actions ────────────────────────────────────────────────────
            if (isMain)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text('This is the main photo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (!isMain)
              ListTile(
                leading:
                    const Icon(Icons.star_outline, color: Colors.amber),
                title: const Text('Set as main photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setAsMain(index);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                _plant.sightings.length == 1
                    ? 'Remove photo & delete plant'
                    : 'Remove photo',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (_plant.sightings.length == 1) {
                  _confirmRemoveLastPhoto();
                } else {
                  _removePhoto(index);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── hero image ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            title: Text(_plant.commonName),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_plant.mainImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                      color: Color(0xFFE8F5E9),
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey, size: 48),
                      ),
                    ),
                  ),
                  // gradient fade so the card feels like it slides over
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black38],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── info card — overlaps bottom of hero image ─────────────────────
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _plant.commonName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _plant.scientificName,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _plant.family,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_plant.referenceImageUrls.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PlantReferenceScreen(
                              imageUrls: _plant.referenceImageUrls,
                              commonName: _plant.commonName,
                              scientificName: _plant.scientificName,
                              family: _plant.family,
                            ),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green[300]!, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.5),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: _plant.referenceImageUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorWidget: (ctx, url, err) =>
                                      const SizedBox.shrink(),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.black38,
                                  child: const Icon(Icons.open_in_full,
                                      color: Colors.white, size: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Photos (${_plant.sightings.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Photo grid — each cell: image + confidence + date below
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final isMain = i == 0;
                  return GestureDetector(
                    onTap: () => _showOptions(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_plant.sightings[i].imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                              color: Color(0xFFE8F5E9),
                              child: Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                          // main badge — top left
                          if (isMain)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[700],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        size: 11, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'Main',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // confidence pill — bottom left
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(_plant.confidence * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _plant.sightings.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
                childAspectRatio: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
