import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TrefleService {
  static String get _functionUrl =>
      '${dotenv.env['SUPABASE_URL']}/functions/v1/identify-plant';

  static String get _apiKey => dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

  static const _fungalFamilies = {
    'Agaricaceae', 'Amanitaceae', 'Boletaceae', 'Cantharellaceae',
    'Russulaceae', 'Polyporaceae', 'Strophariaceae', 'Cortinariaceae',
    'Tricholomataceae', 'Morchellaceae', 'Pleurotaceae', 'Marasmiaceae',
    'Suillaceae', 'Ganodermataceae', 'Fomitopsidaceae', 'Hymenochaetaceae',
    'Phallaceae', 'Lycoperdaceae', 'Sclerodermataceae', 'Paxillaceae',
    'Gomphaceae', 'Hydnaceae', 'Sparassidaceae', 'Clavariaceae',
    'Tremellaceae', 'Auriculariaceae', 'Dacrymycetaceae', 'Nidulariaceae',
    'Psathyrellaceae', 'Inocybaceae', 'Hymenogastraceae', 'Meruliaceae',
  };

  static const _growthFormToTag = {
    'tree': 'Tree',
    'shrub': 'Shrub',
    'subshrub': 'Shrub',
    'herb': 'Herb',
    'forb/herb': 'Herb',
    'graminoid': 'Grass',
    'vine': 'Vine',
    'fern': 'Fern',
  };

  static final Map<String, List<String>> _cache = {};

  Future<List<String>> getTags(String scientificName, String family) async {
    final cacheKey = scientificName.trim().toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[Trefle] cache hit for "$scientificName": ${_cache[cacheKey]}');
      return List<String>.from(_cache[cacheKey]!);
    }

    final tags = <String>[];

    if (_fungalFamilies.contains(family)) tags.add('Mushroom');

    try {
      final cleaned = scientificName.trim().replaceAll(RegExp(r'\s*×\s*'), ' ').trim();
      final twoWord = cleaned.split(RegExp(r'\s+')).take(2).join(' ');
      final candidates = [cleaned, if (twoWord != cleaned) twoWord];

      int? speciesId;
      for (final candidate in candidates) {
        speciesId = await _searchId(candidate);
        if (speciesId != null) {
          debugPrint('[Trefle] matched id=$speciesId via "$candidate"');
          break;
        }
        debugPrint('[Trefle] no match for "$candidate"');
      }

      if (speciesId == null) {
        final gbifRaw = await _gbifCanonicalName(twoWord);
        if (gbifRaw != null) {
          final gbifName = gbifRaw.split(RegExp(r'\s+')).take(2).join(' ');
          if (!candidates.map((c) => c.toLowerCase()).contains(gbifName.toLowerCase())) {
            debugPrint('[Trefle] trying GBIF canonical name "$gbifName"');
            speciesId = await _searchId(gbifName);
            if (speciesId != null) {
              debugPrint('[Trefle] matched id=$speciesId via GBIF canonical "$gbifName"');
            }
          }
        }
      }

      if (speciesId == null) {
        debugPrint('[Trefle] no entry found for "$scientificName"');
        _cache[cacheKey] = List<String>.from(tags);
        return tags;
      }

      final detailUri = Uri.parse('$_functionUrl?action=trefle-detail&id=$speciesId');
      final detailRes = await http.get(detailUri, headers: {'apiKey': _apiKey})
          .timeout(const Duration(seconds: 10));

      if (detailRes.statusCode != 200) {
        debugPrint('[Trefle] detail HTTP ${detailRes.statusCode}');
        _cache[cacheKey] = List<String>.from(tags);
        return tags;
      }

      final detailJson = jsonDecode(detailRes.body) as Map<String, dynamic>;
      final data = detailJson['data'] as Map<String, dynamic>?;
      if (data == null) {
        _cache[cacheKey] = List<String>.from(tags);
        return tags;
      }

      if (data['edible'] == true) tags.add('Edible');
      if (data['medicinal'] == true) tags.add('Medicinal');

      final specs = data['specifications'] as Map<String, dynamic>?;
      final toxicity = specs?['toxicity'] as String?;
      final poisonous = data['poisonous_to_humans'];
      final isToxic =
          (toxicity != null && toxicity.isNotEmpty && toxicity != 'none') ||
          (poisonous != null && poisonous != false && poisonous != 0);
      if (isToxic) tags.add('Toxic');

      final growthHabit = (specs?['growth_habit'] as String?)?.toLowerCase();
      final growthForm = (specs?['growth_form'] as String?)?.toLowerCase();
      final growthTag = _growthFormToTag[growthHabit] ?? _growthFormToTag[growthForm];
      if (growthTag != null) tags.add(growthTag);

      final flower = data['flower'] as Map<String, dynamic>?;
      if (flower?['conspicuous'] == true) tags.add('Flower');

      debugPrint('[Trefle] final tags for "$scientificName": $tags');
    } catch (e) {
      debugPrint('[Trefle] error: $e');
    }

    _cache[cacheKey] = List<String>.from(tags);
    return tags;
  }

  Future<int?> _searchId(String name) async {
    try {
      final uri = Uri.parse(
        '$_functionUrl?action=trefle-search&name=${Uri.encodeComponent(name)}',
      );
      final res = await http.get(uri, headers: {'apiKey': _apiKey})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) return null;

      final nameLower = name.toLowerCase();
      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final resultName = (map['scientific_name'] as String? ?? '').toLowerCase();
        if (resultName.startsWith(nameLower)) {
          return map['id'] as int?;
        }
      }
      debugPrint('[Trefle] search returned results but none matched "$name"');
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _gbifCanonicalName(String name) async {
    try {
      final uri = Uri.parse(
        '$_functionUrl?action=gbif&name=${Uri.encodeComponent(name)}',
      );
      final res = await http.get(uri, headers: {'apiKey': _apiKey})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final confidence = json['confidence'] as int? ?? 0;
      if (confidence < 90) return null;
      return json['canonicalName'] as String?;
    } catch (_) {
      return null;
    }
  }
}
