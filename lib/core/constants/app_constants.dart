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

  // UI constants moved to app_radius.dart and app_shadows.dart

  // Image Transformations
  static const String cloudinaryThumb = 'w_500,c_fill,q_auto,f_auto';
  static const String cloudinaryFull = 'w_1200,c_fill,q_auto,f_auto';
  static const String cloudinaryThumbSmall = 'w_200,c_fill,q_auto,f_auto';

  // Pricing — 3-tier plan structure
  // Explorer (replaces legacy monthly) — casual visitor
  static const double explorerMonthlyPrice = 4.99;
  static const double explorerYearlyPrice = 29.99;
  // Legacy aliases — keep so existing code that reads these doesn't break.
  static const double monthlyPrice = explorerMonthlyPrice;
  static const double yearlyPrice = explorerYearlyPrice;

  // Pro — repeat visitor / researcher (RECOMMENDED)
  static const double proMonthlyPrice = 9.99;
  static const double proYearlyPrice = 59.99;

  // Lifetime — local guide / superfan one-time purchase
  static const double lifetimePrice = 49.99;

  static const int trialDays = 3;

  /// Payment methods accepted — surfaced in the upgrade screen and payment
  /// form. Order: card networks first, then mobile-money for local audience.
  static const List<String> acceptedPaymentMethods = [
    'Visa',
    'Mastercard',
    'Amex',
    'PayPal',
    'M-Pesa',
    'Google Pay',
  ];

  // Animation Durations moved to app_durations.dart
  // Map
  static const double defaultZoom = 15.0;
  static const double markerZoom = 17.0;
  static const double routePolylineWidth = 4.0;

  // Stone Town core — the heritage site cluster sits inside this box.
  // It is used to position markers and as the default centre for the
  // heritage map; routing and the map viewport use the wider Unguja
  // bounds defined below.
  //
  //   south-west: Mizingani Road / harbour (-6.1680, 39.1830)
  //   north-east: Forodhani Gardens / Old Fort (-6.1570, 39.1980)
  //
  // Roughly a 1.4 km × 1.7 km box covering the UNESCO heritage peninsula.
  static const double stoneTownMinLat = -6.1680;
  static const double stoneTownMaxLat = -6.1570;
  static const double stoneTownMinLng = 39.1830;
  static const double stoneTownMaxLng = 39.1980;

  // Wider camera bounds for the admin picker map (~20 % buffer outward from
  // the strict Stone Town box). When the camera constraint uses the tight box
  // the user can accidentally zoom out past its edge; the resulting null from
  // CameraConstraint.contain trips flutter_map's internal assertion and shows
  // the red "Access Blocked" overlay. The wider bounds give comfortable scroll
  // room without letting the camera escape Stone Town's neighbourhood.
  static const double stoneTownPickerMinLat = -6.1740; // ~20% south buffer
  static const double stoneTownPickerMaxLat = -6.1510; // ~20% north buffer
  static const double stoneTownPickerMinLng = 39.1796; // ~20% west buffer
  static const double stoneTownPickerMaxLng = 39.2014; // ~20% east buffer

  // Default camera centre — Forodhani Gardens waterfront, well-mapped on OSM.
  static const double stoneTownCentreLat = -6.1619;
  static const double stoneTownCentreLng = 39.1936;

  // Unguja (Zanzibar main island) — used for the camera viewport and
  // routing validation. Covers the whole island including Nungwi/Mnemba
  // in the north, the airport in the west, and the south coast.
  //
  //   south-west: ~ -6.50, 39.10
  //   north-east: ~ -6.10, 39.55
  static const double ungujaMinLat = -6.50;
  static const double ungujaMaxLat = -6.10;
  static const double ungujaMinLng = 39.10;
  static const double ungujaMaxLng = 39.55;

  // Default island-wide centre.
  static const double ungujaCentreLat = -6.30;
  static const double ungujaCentreLng = 39.30;

  // Map zoom clamp.
  static const double stoneTownMinZoom = 10.0;
  static const double stoneTownMaxZoom = 19.0;

  // Navigation camera animation duration moved to app_durations.dart
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
  static const String orsApiKey = String.fromEnvironment(
    'ORS_API_KEY',
    defaultValue: '',
  );
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
  static const String keyThemeMode =
      'theme_mode'; // 'light' | 'dark' | 'system'
  static const String keyArrivalAlertsEnabled = 'arrival_alerts_enabled';
  // PR-B settings — read/write via SharedPrefsService.
  static const String keyArrivalAlertsRadiusM = 'arrival_alerts_radius_m';

  static const String keyDistanceUnits =
      'distance_units'; // 'metric' | 'imperial'
  static const String keyReduceMotion = 'reduce_motion';
  static const String keyPlaybackSpeed = 'playback_speed'; // double as string
  static const String keyAutoPlayOnArrival = 'auto_play_on_arrival';

  // Runtime config keys — values that admins change through
  // admin_settings_screen.dart without rebuilding the app. Backing store
  // is SharedPreferences; see [RuntimeConfigService].
  static const String keyFreeAudioMaxSeconds = 'free_audio_max_seconds';
  static const String keyOrsApiKey = 'ors_api_key';
  static const String keyMaintenanceMode = 'maintenance_mode';

  // Map providers
  /// Map provider identifiers. 'open' is the default key-free path.
  static const String mapProviderOpen = 'open';
  static const String mapProviderGoogle = 'google';

  // Firestore Collections
  static const String sitesCollection = 'sites';
  static const String usersCollection = 'users';
  static const String rolesCollection = 'roles';
  static const String activitiesCollection = 'activities';

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
