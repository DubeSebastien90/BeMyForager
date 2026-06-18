import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../widgets/plant_card.dart' show tagColor;

class PlantReferenceScreen extends StatefulWidget {
  final List<String> imageUrls;
  final String commonName;
  final String scientificName;
  final String family;
  final List<String> tags;

  const PlantReferenceScreen({
    super.key,
    required this.imageUrls,
    required this.commonName,
    required this.scientificName,
    required this.family,
    this.tags = const [],
  });

  @override
  State<PlantReferenceScreen> createState() => _PlantReferenceScreenState();
}

class _PlantReferenceScreenState extends State<PlantReferenceScreen> {
  int _currentPage = 0;

  String get _genus {
    final parts = widget.scientificName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : widget.scientificName;
  }

  String get _speciesEpithet {
    final parts = widget.scientificName.trim().split(' ');
    return parts.length >= 2 ? parts.sublist(1).join(' ') : '';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final urls = widget.imageUrls;
    final hasMultiple = urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── image area ─────────────────────────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasMultiple)
                  PageView.builder(
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, i) => _ImagePage(imageUrl: urls[i]),
                  )
                else if (urls.isNotEmpty)
                  _ImagePage(imageUrl: urls.first)
                else
                  const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: Colors.white38, size: 64),
                  ),

                // back button
                Positioned(
                  top: topPadding + 8,
                  left: 12,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),

                // PlantNet source badge
                Positioned(
                  top: topPadding + 14,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.eco_outlined,
                            color: Colors.white70, size: 12),
                        SizedBox(width: 4),
                        Text('PlantNet',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),

                // page dots (multiple images) or pinch hint (single image)
                if (hasMultiple)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        urls.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _currentPage ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  )
              ],
            ),
          ),

          // ── info panel ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // name + leaf icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.commonName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.scientificName,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.eco,
                          color: Colors.green[600], size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const _SectionHeader(label: 'Taxonomy'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Family',
                  value: widget.family,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.account_tree_outlined,
                  label: 'Genus',
                  value: _genus,
                ),
                if (_speciesEpithet.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.spa_outlined,
                    label: 'Species',
                    value: _speciesEpithet,
                    italic: true,
                  ),
                ],
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionHeader(label: 'Characteristics'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.tags
                        .map((t) => _ReferenceTagChip(tag: t))
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

class _ImagePage extends StatelessWidget {
  final String imageUrl;
  const _ImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // blurred fill background
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          color: Colors.black54,
          colorBlendMode: BlendMode.darken,
        ),
        // sharp full image
        Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 64),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey[400],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(height: 1, color: Colors.grey[200])),
      ],
    );
  }
}

class _ReferenceTagChip extends StatelessWidget {
  final String tag;
  const _ReferenceTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = tagColor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool italic;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
