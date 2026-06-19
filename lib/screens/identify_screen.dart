import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'plant_result_screen.dart';

class IdentifyScreen extends StatefulWidget {
  final VoidCallback onPlantSaved;

  const IdentifyScreen({super.key, required this.onPlantSaved});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (xFile == null || !mounted) return;
    final name = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PlantResultScreen(imageFile: File(xFile.path)),
      ),
    );
    if (name != null && mounted) widget.onPlantSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.yard_outlined, size: 90, color: Colors.green[200]),
          const SizedBox(height: 20),
          Text(
            'identify_title'.tr(),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'identify_subtitle'.tr(),
            style: TextStyle(color: Colors.grey[500], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text('camera'.tr(), textAlign: TextAlign.center),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[300]!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('gallery'.tr(), textAlign: TextAlign.center),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.green[700],
                    side: BorderSide(color: Colors.green[300]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
