import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PlantIdentificationResult {
  final String scientificName;
  final String commonName;
  final String family;
  final double confidence;
  final List<String> imageUrls; // up to 3 medium-size reference photos

  const PlantIdentificationResult({
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.confidence,
    this.imageUrls = const [],
  });

  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
}

class PlantNetService {
  static const String _baseUrl =
      'https://my-api.plantnet.org/v2/identify/all';

  /// Returns all candidates ordered by confidence (best first).
  Future<List<PlantIdentificationResult>> identify(File imageFile) async {
    final apiKey = dotenv.env['PLANTNET_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'your_api_key_here') {
      throw Exception('PlantNet API key is not configured in .env');
    }

    final uri = Uri.parse(
        '$_baseUrl?api-key=$apiKey&lang=en&include-related-images=true');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('images', imageFile.path),
    );
    request.fields['organs'] = 'auto';

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      final body = response.body;
      String message;
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        message = decoded['message'] as String? ?? body;
      } catch (_) {
        message = body;
      }
      throw Exception('PlantNet error ${response.statusCode}: $message');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>;
    if (results.isEmpty) {
      throw Exception('No plant could be identified from this image');
    }

    return results.map((item) {
      final r = item as Map<String, dynamic>;
      final species = r['species'] as Map<String, dynamic>;
      final commonNames = (species['commonNames'] as List<dynamic>?) ?? [];
      final familyObj = species['family'] as Map<String, dynamic>?;

      // grab up to 3 medium URLs from related images
      final imageUrls = <String>[];
      final images = r['images'] as List<dynamic>?;
      if (images != null) {
        for (final img in images.take(3)) {
          final imgMap = img as Map<String, dynamic>;
          final urlMap = imgMap['url'] as Map<String, dynamic>?;
          final url = urlMap?['m'] as String?;
          if (url != null) imageUrls.add(url);
        }
      }

      return PlantIdentificationResult(
        scientificName:
            species['scientificNameWithoutAuthor'] as String? ?? 'Unknown',
        commonName: commonNames.isNotEmpty
            ? commonNames.first as String
            : species['scientificNameWithoutAuthor'] as String? ?? 'Unknown',
        family:
            familyObj?['scientificNameWithoutAuthor'] as String? ?? 'Unknown',
        confidence: (r['score'] as num).toDouble(),
        imageUrls: imageUrls,
      );
    }).toList();
  }
}
