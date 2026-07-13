class AppConstants {
  AppConstants._();

  // TTS
  static const int freeAudioMaxSeconds = 30;
  static const double defaultSpeechRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;

  // Location
  static const double defaultRadiusMeters = 30.0;
  static const int locationUpdateIntervalMs = 5000;
  static const double locationAccuracyMeters = 10.0;

  // UI
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  static const double minTouchTarget = 48.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Image Transformations
  static const String cloudinaryThumb = 'w_500,c_fill,q_auto,f_auto';
  static const String cloudinaryFull = 'w_1200,c_fill,q_auto,f_auto';
  static const String cloudinaryThumbSmall = 'w_200,c_fill,q_auto,f_auto';

  // Pricing
  static const double monthlyPrice = 4.99;
  static const double yearlyPrice = 29.99;
  static const int trialDays = 3;

  /// Payment methods accepted via Google Play Billing — surfaced in the
  /// upgrade screen FAQ. Order is intentional: mobile-money first for
  /// the local audience, then card networks.
  static const List<String> acceptedPaymentMethods = [
    'M-Pesa',
    'Tigo Pesa',
    'Airtel Money',
    'Visa',
    'Mastercard',
  ];

  // Animation Durations (ms)
  static const int animationFast = 200;
  static const int animationNormal = 300;
  static const int animationSlow = 500;

  // Map
  static const double defaultZoom = 15.0;
  static const double markerZoom = 17.0;
  static const double routePolylineWidth = 4.0;

  // Stone Town core — the camera is clamped to this box. Everything outside
  // is rejected by the routing service too, so the user never sees OSM tiles
  // for the rest of Unguja or the Indian Ocean.
  //
  //   south-west: Mizingani Road / harbour (-6.1680, 39.1830)
  //   north-east: Forodhani Gardens / Old Fort (-6.1570, 39.1980)
  //
  // Roughly a 1.4 km × 1.7 km box covering the UNESCO heritage peninsula.
  static const double stoneTownMinLat = -6.1680;
  static const double stoneTownMaxLat = -6.1570;
  static const double stoneTownMinLng = 39.1830;
  static const double stoneTownMaxLng = 39.1980;

  // Default camera centre — Forodhani Gardens waterfront, well-mapped on OSM.
  static const double stoneTownCentreLat = -6.1619;
  static const double stoneTownCentreLng = 39.1936;

  // Map zoom clamp.
  static const double stoneTownMinZoom = 14.0;
  static const double stoneTownMaxZoom = 19.0;

  // Navigation camera animation duration (ms).
  static const int navigationAnimationMs = 220;

  // Routing providers. Defaults can be overridden at build time via
  // --dart-define so secrets (API keys) never have to live in source
  // control. Both URLs are open-source endpoints that work without
  // billing accounts.
  //
  //   flutter run --dart-define=ORS_API_KEY=<your key>
  //
  // When ORS_API_KEY is empty (the default), the routing service falls
  // back to the public OSRM demo and adds `radiuses=25;25` so the
  // "nearest road" snap is bounded — this is what fixed the
  // cross-country routing bug.
  static const String orsBaseUrl = String.fromEnvironment(
    'ORS_BASE_URL',
    defaultValue:
        'https://api.openrouteservice.org/v2/directions/foot-walking/geojson',
  );
  static const String orsApiKey =
      String.fromEnvironment('ORS_API_KEY', defaultValue: '');
  static const String osrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  /// Max plausible walking distance (meters) for a *single* route inside
  /// Stone Town. Anything longer gets clipped to a straight line so we
  /// never render a transcontinental polyline — the routing engine
  /// sometimes returns long-distance geometry when the origin can't be
  /// resolved cleanly (no GPS yet, OSRM demo rate limit, etc.).
  static const double maxRouteDistanceMeters = 8000;

  /// Tile-cache age (days). Tiles older than this on disk are
  /// re-fetched on next miss. We don't proactively evict.
  static const int tileCacheMaxAgeDays = 30;

  /// Route-cache age (days). Cached routes older than this are treated
  /// as a cache miss and re-fetched from OSRM — long enough that most
  /// repeat visits in a holiday week will hit the cache, short enough
  /// that admin-moved doorways don't keep pointing at an old road.
  static const int routeCacheMaxAgeDays = 30;

  /// Set this to a real Google Maps API key in production builds to enable
  /// the live-navigation screen. When null, the "Navigate" buttons in the
  /// app show a friendly snackbar instead of opening NavigationScreen
  /// (which uses google_maps_flutter — broken on emulators / devices
  /// without Google Play services, or without billing enabled).
  ///
  /// The rest of the map experience (browse, view, picker) uses
  /// flutter_map + OpenStreetMap and works without any key.
  static const String? googleMapsApiKey = null;

  // SharedPreferences Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyUiLanguage = 'ui_language';
  static const String keyAudioLanguage = 'audio_language';
  static const String keyItinerary = 'itinerary';
  static const String keyShowPremiumOffer = 'show_premium_offer';
  static const String keyIsPremiumDemo = 'is_premium_demo';
  static const String keyUserId = 'user_id';
  static const String keyFavorites = 'favorites';
  static const String keyMapProvider = 'map_provider'; // 'open' | 'google'
  static const String keyThemeMode = 'theme_mode'; // 'light' | 'dark' | 'system'
  static const String keyArrivalAlertsEnabled = 'arrival_alerts_enabled';

  // Map providers
  /// Map provider identifiers. 'open' is the default key-free path.
  static const String mapProviderOpen = 'open';
  static const String mapProviderGoogle = 'google';

  // Firestore Collections
  static const String sitesCollection = 'sites';
  static const String usersCollection = 'users';
  static const String rolesCollection = 'roles';

  // Site Categories
  static const List<String> siteCategories = [
    'historic',
    'cultural',
    'religious',
    'architecture',
  ];

  // TTS Languages
  static const List<String> ttsLanguages = [
    'en',
    'sw',
    'fr',
    'de',
    'ar',
    'it',
    'es',
  ];

  // Free TTS Languages
  static const List<String> freeTtsLanguages = ['en', 'sw'];

  // UI Languages
  static const List<String> uiLanguages = ['en', 'sw'];
}
