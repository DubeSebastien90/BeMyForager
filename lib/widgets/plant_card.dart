import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../screens/plant_reference_screen.dart';

class PlantCard extends StatelessWidget {
  final Plant plant;
  /// When set, displays this image instead of the plant's main photo.
  /// Used to show a location-specific sighting in grouped/search views.
  final String? overrideImagePath;

  const PlantCard({super.key, required this.plant, this.overrideImagePath});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // main user photo with photo count badge
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(overrideImagePath ?? plant.mainImagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const ColoredBox(
                    color: Color(0xFFE8F5E9),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${plant.sightings.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // info row: text on the left, reference thumbnail on the right
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.commonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plant.scientificName,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        plant.family,
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // reference thumbnail — tap opens PlantReferenceScreen
                if (plant.referenceImageUrls.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => PlantReferenceScreen(
                          imageUrls: plant.referenceImageUrls,
                          commonName: plant.commonName,
                          scientificName: plant.scientificName,
                          family: plant.family,
                          tags: plant.tags,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green[200]!, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.5),
                        child: CachedNetworkImage(
                          imageUrl: plant.referenceImageUrl!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // tags row
          if (plant.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
              child: Row(
                children: [
                  ...plant.tags.take(3).map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _TagChip(tag: tag),
                        ),
                      ),
                  if (plant.tags.length > 3)
                    _TagChip(tag: '+${plant.tags.length - 3}', isOverflow: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color tagColor(String tag) {
  return switch (tag) {
    'Edible' => Colors.green,
    'Medicinal' => Colors.blue,
    'Toxic' => Colors.red,
    'Tree' => const Color(0xFF5D4037),
    'Shrub' => Colors.teal,
    'Herb' => Colors.lightGreen,
    'Grass' => const Color(0xFF9E9D24),
    'Flower' => Colors.pink,
    'Vine' => Colors.indigo,
    'Fern' => Colors.cyan,
    'Mushroom' => Colors.orange,
    _ => Colors.grey,
  };
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool isOverflow;

  const _TagChip({required this.tag, this.isOverflow = false});

  @override
  Widget build(BuildContext context) {
    final color = isOverflow ? Colors.grey : tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
