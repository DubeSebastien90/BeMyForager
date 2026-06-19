import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;
  static final _crashlytics = FirebaseCrashlytics.instance;

  static void recordError(Object error, StackTrace? stack,
      {bool fatal = false}) {
    _crashlytics.recordError(error, stack, fatal: fatal);
  }

  static void logPlantIdentified({
    required String scientificName,
    required double confidence,
    required String lang,
  }) {
    _analytics.logEvent(
      name: 'plant_identified',
      parameters: {
        'scientific_name': scientificName,
        'confidence_pct': (confidence * 100).round(),
        'lang': lang,
      },
    );
  }

  static void logPlantSaved({
    required String scientificName,
    required String action, // 'new' | 'use_as_main' | 'add_to_gallery'
  }) {
    _analytics.logEvent(
      name: 'plant_saved',
      parameters: {
        'scientific_name': scientificName,
        'action': action,
      },
    );
  }

  static void logLanguageChanged(String lang) {
    _analytics.logEvent(
        name: 'language_changed', parameters: {'lang': lang});
  }

  static void logDemoLoaded() {
    _analytics.logEvent(name: 'demo_loaded');
  }
}
