import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class PlantLocation {
  final double latitude;
  final double longitude;
  final String? country;
  final String? administrativeArea;
  final String? locality;
  final String? subLocality;
  final String? placeName; // specific POI / park / forest name

  const PlantLocation({
    required this.latitude,
    required this.longitude,
    this.country,
    this.administrativeArea,
    this.locality,
    this.subLocality,
    this.placeName,
  });
}

class LocationService {
  /// Returns the current location with reverse-geocoded placemark data.
  /// Returns null if permission is denied, location is unavailable, or
  /// anything else goes wrong — the app must continue working without it.
  Future<PlantLocation?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[Location] service enabled: $serviceEnabled');
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      debugPrint('[Location] permission before request: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('[Location] permission after request: $permission');
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[Location] permission denied forever');
        return null;
      }

      // Try last known position first — instant and sufficient for city-level geocoding.
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        debugPrint('[Location] using last known position: '
            '${position.latitude}, ${position.longitude}');
      } else {
        // Fall back to a fresh fix using network/WiFi (much faster than GPS).
        debugPrint('[Location] no cached position, fetching fresh (network)…');
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        ).timeout(const Duration(seconds: 15));
        debugPrint('[Location] fresh position: '
            '${position.latitude}, ${position.longitude}');
      }

      String? country;
      String? administrativeArea;
      String? locality;
      String? subLocality;
      String? placeName;

      try {
        debugPrint('[Location] reverse geocoding…');
        final marks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));

        debugPrint('[Location] placemarks count: ${marks.length}');
        if (marks.isNotEmpty) {
          final m = marks.first;
          debugPrint('[Location] raw placemark — '
              'name="${m.name}" '
              'subLocality="${m.subLocality}" '
              'locality="${m.locality}" '
              'adminArea="${m.administrativeArea}" '
              'country="${m.country}"');
          country = _nonEmpty(m.country);
          administrativeArea = _nonEmpty(m.administrativeArea);
          locality = _nonEmpty(m.locality);
          subLocality = _nonEmpty(m.subLocality);
          placeName = _nonEmpty(m.name);
        }
      } catch (e) {
        debugPrint('[Location] geocoding error: $e');
      }

      final result = PlantLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        country: country,
        administrativeArea: administrativeArea,
        locality: locality,
        subLocality: subLocality,
        placeName: placeName,
      );
      debugPrint('[Location] result: placeName=$placeName subLocality=$subLocality '
          'locality=$locality adminArea=$administrativeArea country=$country');
      return result;
    } catch (e) {
      debugPrint('[Location] top-level error: $e');
      return null;
    }
  }

  String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
}
