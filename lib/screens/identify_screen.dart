import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'plant_reference_screen.dart';
import 'package:uuid/uuid.dart';
import '../models/plant.dart';
import '../models/sighting.dart';
import '../services/location_service.dart';
import '../services/plant_net_service.dart';
import '../services/storage_service.dart';
import '../services/trefle_service.dart';
import '../widgets/plant_card.dart' show tagColor;

class IdentifyScreen extends StatefulWidget {
  final VoidCallback onPlantSaved;

  const IdentifyScreen({super.key, required this.onPlantSaved});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  final _picker = ImagePicker();
  final _service = PlantNetService();
  final _storage = StorageService();
  final _locationService = LocationService();
  final _trefleService = TrefleService();
  static const _uuid = Uuid();

  File? _image;
  PlantIdentificationResult? _result;
  List<PlantIdentificationResult> _alternatives = [];
  Plant? _existingPlant;
  bool _identifying = false;
  String? _error;
  PlantLocation? _location;
  List<String> _tags = [];

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (xFile == null) return;
    setState(() {
      _image = File(xFile.path);
      _result = null;
      _alternatives = [];
      _existingPlant = null;
      _error = null;
      _location = null;
      _tags = [];
    });
    await _identify();
  }

  Future<void> _identify() async {
    if (_image == null) return;
    setState(() {
      _identifying = true;
      _error = null;
    });
    try {
      // location runs in parallel with PlantNet; Trefle starts after we have the scientific name
      final locationFuture = _locationService.getCurrentLocation();
      final results = await _service.identify(_image!);
      final best = results.first;
      final topScore = best.confidence;

      // Filter alternatives first so we only fire Trefle for species we'll show.
      final alts = results
          .skip(1)
          .where((r) =>
              r.confidence >= topScore * 0.25 && r.confidence >= 0.05)
          .take(3)
          .toList();

      // Fire Trefle for best + shown alternatives in parallel with location.
      final trefleFutures = [best, ...alts]
          .map((r) => _trefleService.getTags(r.scientificName, r.family))
          .toList();
      _location = await locationFuture;
      final allTags = await Future.wait(trefleFutures);
      _tags = allTags.first;
      final all = await _storage.loadPlants();

      final match = all.where((p) =>
          p.scientificName.toLowerCase() == best.scientificName.toLowerCase());

      setState(() {
        _result = best;
        _alternatives = alts;
        _existingPlant = match.isNotEmpty ? match.first : null;
        _identifying = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _identifying = false;
      });
    }
  }

  /// Swap an alternative in as the active result, re-check for duplicates.
  Future<void> _selectAlternative(PlantIdentificationResult alt) async {
    // Both already cached — fire in parallel, await separately to keep types clean.
    final allFuture = _storage.loadPlants();
    final tagsFuture = _trefleService.getTags(alt.scientificName, alt.family);
    final all = await allFuture;
    final altTags = await tagsFuture;
    final match = all.where((p) =>
        p.scientificName.toLowerCase() == alt.scientificName.toLowerCase());
    setState(() {
      final prev = _result!;
      _alternatives = [
        prev,
        ..._alternatives.where(
            (a) => a.scientificName != alt.scientificName),
      ];
      _result = alt;
      _tags = altTags;
      _existingPlant = match.isNotEmpty ? match.first : null;
    });
  }

  // ── save actions ──────────────────────────────────────────────────────────

  Sighting _buildSighting(String imagePath) => Sighting(
    imagePath: imagePath,
    capturedAt: DateTime.now(),
    latitude: _location?.latitude,
    longitude: _location?.longitude,
    country: _location?.country,
    administrativeArea: _location?.administrativeArea,
    locality: _location?.locality,
    subLocality: _location?.subLocality,
    placeName: _location?.placeName,
  );

  Future<void> _saveNew() async {
    if (_image == null || _result == null) return;
    debugPrint('[SaveNew] location at save time: '
        'lat=${_location?.latitude} lng=${_location?.longitude} '
        'locality=${_location?.locality} country=${_location?.country}');
    final path = await _storage.copyImageToPermanentStorage(_image!.path);
    final now = DateTime.now();
    final plant = Plant(
      id: _uuid.v4(),
      sightings: [_buildSighting(path)],
      scientificName: _result!.scientificName,
      commonName: _result!.commonName,
      family: _result!.family,
      confidence: _result!.confidence,
      createdAt: now,
      referenceImageUrls: _result!.imageUrls,
      tags: _tags,
    );
    final all = await _storage.loadPlants();
    all.add(plant);
    await _storage.savePlants(all);
    _finish(plant.commonName);
  }

  Future<void> _useAsMain() async {
    if (_image == null || _existingPlant == null) return;
    final path = await _storage.copyImageToPermanentStorage(_image!.path);
    var updated = _existingPlant!.copyWith(
      sightings: [_buildSighting(path), ..._existingPlant!.sightings],
    );
    if (updated.tags.isEmpty && _tags.isNotEmpty) {
      updated = updated.copyWith(tags: _tags);
    }
    await _patchPlant(updated);
    _finish(_existingPlant!.commonName);
  }

  Future<void> _addToGallery() async {
    if (_image == null || _existingPlant == null) return;
    final path = await _storage.copyImageToPermanentStorage(_image!.path);
    var updated = _existingPlant!.copyWith(
      sightings: [..._existingPlant!.sightings, _buildSighting(path)],
    );
    if (updated.tags.isEmpty && _tags.isNotEmpty) {
      updated = updated.copyWith(tags: _tags);
    }
    await _patchPlant(updated);
    _finish(_existingPlant!.commonName);
  }

  void _dropPhoto() {
    setState(() {
      _image = null;
      _result = null;
      _alternatives = [];
      _existingPlant = null;
      _tags = [];
    });
  }

  Future<void> _patchPlant(Plant updated) async {
    final all = await _storage.loadPlants();
    final idx = all.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      all[idx] = updated;
      await _storage.savePlants(all);
    }
  }

  void _finish(String name) {
    widget.onPlantSaved();
    setState(() {
      _image = null;
      _result = null;
      _alternatives = [];
      _existingPlant = null;
      _tags = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added to your collection!'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_image == null) ...[
            const SizedBox(height: 40),
            Icon(Icons.yard_outlined, size: 90, color: Colors.green[200]),
            const SizedBox(height: 20),
            Text(
              'Identify a Plant',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo or pick one from your gallery\nto identify what plant it is.',
              style: TextStyle(color: Colors.grey[500], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _image!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_identifying) ...[
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Identifying…', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
          ],

          if (_error != null) ...[
            _StatusBox(
              color: Colors.red,
              icon: Icons.error_outline,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 16),
          ],

          if (_result != null) ...[
            _ResultCard(result: _result!, tags: _tags),
            const SizedBox(height: 10),

            // ── alternatives ──────────────────────────────────────────────
            if (_alternatives.isNotEmpty) ...[
              _AlternativesSection(
                alternatives: _alternatives,
                onSelect: _selectAlternative,
              ),
              const SizedBox(height: 10),
            ],

            // ── duplicate or new ──────────────────────────────────────────
            if (_existingPlant != null) ...[
              _StatusBox(
                color: Colors.orange,
                icon: Icons.info_outline,
                child: Text(
                  '${_result!.commonName} is already in your collection.',
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
              const SizedBox(height: 12),
              _DuplicateActions(
                onUseAsMain: _useAsMain,
                onAddToGallery: _addToGallery,
                onDrop: _dropPhoto,
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Collection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Camera / Gallery buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap:
                      _identifying ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap:
                      _identifying ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),

          if (_result != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _image = null;
                _result = null;
                _alternatives = [];
                _existingPlant = null;
                _error = null;
                _tags = [];
              }),
              child: const Text('Start over'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── sub-widgets ───────────────────────────────────────────────────────────────

class _AlternativesSection extends StatelessWidget {
  final List<PlantIdentificationResult> alternatives;
  final Future<void> Function(PlantIdentificationResult) onSelect;

  const _AlternativesSection(
      {required this.alternatives, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Could also be…',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        ...alternatives.map((alt) => _AlternativeTile(
              result: alt,
              onTap: () => onSelect(alt),
            )),
      ],
    );
  }
}

const _thumbPlaceholder = SizedBox(
  width: 48,
  height: 48,
  child: ColoredBox(
    color: Color(0xFFE8F5E9),
    child: Center(
      child: Icon(Icons.eco_outlined, size: 20, color: Colors.grey),
    ),
  ),
);

class _AlternativeTile extends StatelessWidget {
  final PlantIdentificationResult result;
  final VoidCallback onTap;

  const _AlternativeTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: result.imageUrls.isNotEmpty
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PlantReferenceScreen(
                              imageUrls: result.imageUrls,
                              commonName: result.commonName,
                              scientificName: result.scientificName,
                              family: result.family,
                            ),
                          ),
                        )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: result.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: result.imageUrls.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _thumbPlaceholder,
                          errorWidget: (context, url, error) =>
                              _thumbPlaceholder,
                        )
                      : _thumbPlaceholder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.commonName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      result.scientificName,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuplicateActions extends StatelessWidget {
  final VoidCallback onUseAsMain;
  final VoidCallback onAddToGallery;
  final VoidCallback onDrop;

  const _DuplicateActions({
    required this.onUseAsMain,
    required this.onAddToGallery,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onUseAsMain,
            icon: const Icon(Icons.star_outline),
            label: const Text('Use as main image'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddToGallery,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add to gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.green[700],
              side: BorderSide(color: Colors.green[400]!),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onDrop,
            icon: const Icon(Icons.close),
            label: const Text('Drop photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final PlantIdentificationResult result;
  final List<String> tags;

  const _ResultCard({required this.result, this.tags = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // reference photo from PlantNet — tap to view full screen
          if (result.imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => PlantReferenceScreen(
                    imageUrls: result.imageUrls,
                    commonName: result.commonName,
                    scientificName: result.scientificName,
                    family: result.family,
                    tags: tags,
                  ),
                ),
              ),
              child: SizedBox(
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // blurred fill — hides any background bars
                    CachedNetworkImage(
                      imageUrl: result.imageUrls.first,
                      fit: BoxFit.cover,
                      color: Colors.black38,
                      colorBlendMode: BlendMode.darken,
                      placeholder: (context, url) => ColoredBox(
                        color: Colors.green[100]!,
                        child: const Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => ColoredBox(
                        color: Colors.green[100]!,
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.grey[400], size: 36),
                        ),
                      ),
                    ),
                    // full image, never cropped
                    CachedNetworkImage(
                      imageUrl: result.imageUrls.first,
                      fit: BoxFit.contain,
                    ),
                    // "tap to expand" hint
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_full,
                                color: Colors.white, size: 11),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Plant identified!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(result.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _Row(label: 'Common name', value: result.commonName),
                const SizedBox(height: 8),
                _Row(
                    label: 'Scientific name',
                    value: result.scientificName,
                    italic: true),
                const SizedBox(height: 8),
                _Row(label: 'Family', value: result.family),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: tags
                        .map((t) => _IdentifyTagChip(tag: t))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool italic;

  const _Row({required this.label, required this.value, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 115,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Widget child;

  const _StatusBox(
      {required this.color, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: Colors.green[700],
        side: BorderSide(color: Colors.green[300]!),
      ),
    );
  }
}

class _IdentifyTagChip extends StatelessWidget {
  final String tag;
  const _IdentifyTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
