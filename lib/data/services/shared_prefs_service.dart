import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SharedPrefsService {
  static SharedPrefsService? _instance;
  static SharedPreferences? _prefs;

  SharedPrefsService._();

  static Future<SharedPrefsService> getInstance() async {
    if (_instance == null) {
      _instance = SharedPrefsService._();
      _prefs ??= await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  static SharedPrefsService get instance {
    if (_instance == null) {
      throw Exception('SharedPrefsService not initialized. Call getInstance() first.');
    }
    return _instance!;
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('SharedPrefsService not initialized. Call getInstance() first.');
    }
    return _prefs!;
  }

  // First Launch
  bool get isFirstLaunch =>
      _preferences.getBool(AppConstants.keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchComplete() async {
    await _preferences.setBool(AppConstants.keyFirstLaunch, false);
  }

  // UI Language
  String get uiLanguage =>
      _preferences.getString(AppConstants.keyUiLanguage) ?? 'en';

  Future<void> setUiLanguage(String languageCode) async {
    await _preferences.setString(AppConstants.keyUiLanguage, languageCode);
  }

  // Audio Language
  String get audioLanguage =>
      _preferences.getString(AppConstants.keyAudioLanguage) ?? 'en';

  Future<void> setAudioLanguage(String languageCode) async {
    await _preferences.setString(AppConstants.keyAudioLanguage, languageCode);
  }

  // Itinerary
  List<String> get itinerary =>
      _preferences.getStringList(AppConstants.keyItinerary) ?? [];

  Future<void> addToItinerary(String siteId) async {
    final current = itinerary;
    if (!current.contains(siteId)) {
      current.add(siteId);
      await _preferences.setStringList(AppConstants.keyItinerary, current);
    }
  }

  Future<void> removeFromItinerary(String siteId) async {
    final current = itinerary;
    current.remove(siteId);
    await _preferences.setStringList(AppConstants.keyItinerary, current);
  }

  Future<void> clearItinerary() async {
    await _preferences.setStringList(AppConstants.keyItinerary, []);
  }

  bool isInItinerary(String siteId) => itinerary.contains(siteId);

  // Premium Offer
  bool get showPremiumOffer =>
      _preferences.getBool(AppConstants.keyShowPremiumOffer) ?? true;

  Future<void> setShowPremiumOffer(bool show) async {
    await _preferences.setBool(AppConstants.keyShowPremiumOffer, show);
  }

  // User ID
  String? get userId => _preferences.getString(AppConstants.keyUserId);

  Future<void> setUserId(String? id) async {
    if (id == null) {
      await _preferences.remove(AppConstants.keyUserId);
    } else {
      await _preferences.setString(AppConstants.keyUserId, id);
    }
  }

  // Is User Logged In (for skipping welcome screen)
  bool get isUserLoggedIn {
    final userId = _preferences.getString(AppConstants.keyUserId);
    return userId != null && userId.isNotEmpty;
  }

  Future<void> setUserLoggedIn(bool isLoggedIn, {String? userId, String? userRole}) async {
    if (isLoggedIn && userId != null) {
      await _preferences.setString(AppConstants.keyUserId, userId);
      if (userRole != null) {
        await _preferences.setString('user_role', userRole);
      }
    } else {
      await _preferences.remove(AppConstants.keyUserId);
      await _preferences.remove('user_role');
    }
  }

  String? get savedUserRole => _preferences.getString('user_role');

  // Favorites
  List<String> get favorites =>
      _preferences.getStringList(AppConstants.keyFavorites) ?? [];

  Future<void> setFavorites(List<String> favoriteIds) async {
    await _preferences.setStringList(AppConstants.keyFavorites, favoriteIds);
  }

  Future<void> addFavorite(String siteId) async {
    final current = favorites;
    if (!current.contains(siteId)) {
      current.add(siteId);
      await _preferences.setStringList(AppConstants.keyFavorites, current);
    }
  }

  Future<void> removeFavorite(String siteId) async {
    final current = favorites;
    current.remove(siteId);
    await _preferences.setStringList(AppConstants.keyFavorites, current);
  }

  bool isFavorite(String siteId) => favorites.contains(siteId);

  // Clear all
  Future<void> clearAll() async {
    await _preferences.clear();
  }
}