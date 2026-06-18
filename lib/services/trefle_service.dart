import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TrefleService {
  static const _base = 'https://trefle.io/api/v1';

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

  // In-memory cache keyed by lowercase scientific name.
  // Persists for the app session so the same species is never re-fetched.
  static final Map<String, List<String>> _cache = {};

  /// Returns a list of tags for the given species. Never throws — returns
  /// whatever could be determined, or an empty list on failure.
  Future<List<String>> getTags(String scientificName, String family) async {
    final cacheKey = scientificName.trim().toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[Trefle] cache hit for "$scientificName": ${_cache[cacheKey]}');
      return List<String>.from(_cache[cacheKey]!);
    }

    final tags = <String>[];

    // Mushroom detection via PlantNet family — instant, no API call needed.
    if (_fungalFamilies.contains(family)) tags.add('Mushroom');

    try {
      final apiKey = dotenv.env['TREFLE_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        debugPrint('[Trefle] no API key found');
        _cache[cacheKey] = List<String>.from(tags);
        return tags;
      }

      // Build a list of name candidates to try in order:
      //   1. Full name with hybrid × stripped  ("Tulipa × gesneriana" → "Tulipa gesneriana")
      //   2. First two words only              ("Taraxacum officinale var. vulgare" → "Taraxacum officinale")
      // Using a LinkedHashSet preserves insertion order and removes duplicates.
      final cleaned = scientificName.trim().replaceAll(RegExp(r'\s*×\s*'), ' ').trim();
      final twoWord = cleaned.split(RegExp(r'\s+')).take(2).join(' ');
      final candidates = [cleaned, if (twoWord != cleaned) twoWord];

      int? speciesId;
      for (final candidate in candidates) {
        speciesId = await _searchId(candidate, apiKey);
        if (speciesId != null) {
          debugPrint('[Trefle] matched id=$speciesId via "$candidate"');
          break;
        }
        debugPrint('[Trefle] no match for "$candidate"');
      }

      // Last resort: ask GBIF for the canonical name — handles cases where
      // PlantNet (GBIF taxonomy) and Trefle (USDA taxonomy) use different
      // accepted names for the same species due to reclassification.
      if (speciesId == null) {
        final gbifRaw = await _gbifCanonicalName(twoWord);
        if (gbifRaw != null) {
          // GBIF can return trinomials ("Taraxacum officinale subsp. officinale").
          // Truncate to two words so the startsWith check in _searchId works.
          final gbifName = gbifRaw.split(RegExp(r'\s+')).take(2).join(' ');
          if (!candidates.map((c) => c.toLowerCase()).contains(gbifName.toLowerCase())) {
            debugPrint('[Trefle] trying GBIF canonical name "$gbifName" (raw: "$gbifRaw")');
            speciesId = await _searchId(gbifName, apiKey);
            if (speciesId != null) {
              debugPrint('[Trefle] matched id=$speciesId via GBIF canonical "$gbifName"');
            }
          }
        }
      }

      if (speciesId == null) {
        debugPrint('[Trefle] no entry found for "$scientificName" — species absent from Trefle');
        _cache[cacheKey] = List<String>.from(tags);
        return tags;
      }

      // Fetch full species detail for all tag fields.
      final detailUri = Uri.parse('$_base/species/$speciesId?token=$apiKey');
      final detailRes = await http.get(detailUri).timeout(const Duration(seconds: 10));

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

      // ── edible / medicinal ────────────────────────────────────────────────
      if (data['edible'] == true) tags.add('Edible');
      if (data['medicinal'] == true) tags.add('Medicinal');

      // ── toxic ─────────────────────────────────────────────────────────────
      final specs = data['specifications'] as Map<String, dynamic>?;
      final toxicity = specs?['toxicity'] as String?;
      final poisonous = data['poisonous_to_humans'];
      final isToxic =
          (toxicity != null && toxicity.isNotEmpty && toxicity != 'none') ||
          (poisonous != null && poisonous != false && poisonous != 0);
      if (isToxic) tags.add('Toxic');

      // ── growth form → visual category ─────────────────────────────────────
      // growth_habit uses standard USDA categories (Tree/Shrub/Forb/herb…)
      // and is more reliable than growth_form which can return values like
      // "Multiple Stem" that don't map to anything useful.
      final growthHabit = (specs?['growth_habit'] as String?)?.toLowerCase();
      final growthForm = (specs?['growth_form'] as String?)?.toLowerCase();
      final growthTag = _growthFormToTag[growthHabit] ?? _growthFormToTag[growthForm];
      if (growthTag != null) tags.add(growthTag);
      debugPrint('[Trefle] growth_habit="$growthHabit" growth_form="$growthForm" → $growthTag');

      // ── flower ────────────────────────────────────────────────────────────
      final flower = data['flower'] as Map<String, dynamic>?;
      if (flower?['conspicuous'] == true) tags.add('Flower');

      debugPrint('[Trefle] final tags for "$scientificName": $tags');
    } catch (e) {
      debugPrint('[Trefle] error: $e');
    }

    _cache[cacheKey] = List<String>.from(tags);
    return tags;
  }

  /// Searches Trefle for [name] and returns the species ID only if a result
  /// whose scientific name starts with [name] is found. This prevents assigning
  /// tags from a wrong-but-similarly-named species (e.g. returning
  /// "Vaccinium myrtilloides" when we searched "Vaccinium myrtillus").
  Future<int?> _searchId(String name, String apiKey) async {
    try {
      final uri = Uri.parse(
        '$_base/species/search?q=${Uri.encodeComponent(name)}&token=$apiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
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

  /// Asks the free GBIF name-match API for the canonical two-word name.
  /// Returns null if confidence is low or the call fails.
  /// No API key required.
  Future<String?> _gbifCanonicalName(String name) async {
    try {
      final uri = Uri.parse(
        'https://api.gbif.org/v1/species/match'
        '?name=${Uri.encodeComponent(name)}&strict=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final confidence = json['confidence'] as int? ?? 0;
      if (confidence < 90) return null; // low confidence = wrong species risk
      return json['canonicalName'] as String?;
    } catch (_) {
      return null;
    }
  }
}
