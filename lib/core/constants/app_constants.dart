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

  // Animation Durations (ms)
  static const int animationFast = 200;
  static const int animationNormal = 300;
  static const int animationSlow = 500;

  // Map
  static const double defaultZoom = 15.0;
  static const double markerZoom = 17.0;
  static const double routePolylineWidth = 4.0;

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