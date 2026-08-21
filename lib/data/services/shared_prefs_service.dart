import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SharedPrefsService {
  SharedPrefsService._();
  static SharedPrefsService? _instance;
  static SharedPreferences? _prefs;

  /// Fires after every successful `set*` write. Subscribers re-read the
  /// pref they care about — this keeps the get/set surface intact and
  /// avoids per-key streams. Cheap when nobody is listening.
  final SharedPrefsChangeNotifier prefsChanged = SharedPrefsChangeNotifier();

  /// Public listener surface so callers can `addListener` /
  /// `removeListener` without exposing the notifier for dispose.
  ChangeNotifier get onPrefsChanged => prefsChanged;

  void _notify() {
    prefsChanged.notifySubscribers();
  }

  static Future<SharedPrefsService> getInstance() async {
    if (_instance == null) {
      _instance = SharedPrefsService._();
      _prefs ??= await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  static SharedPrefsService get instance {
    if (_instance == null) {
      throw Exception(
        'SharedPrefsService not initialized. Call getInstance() first.',
      );
    }
    return _instance!;
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception(
        'SharedPrefsService not initialized. Call getInstance() first.',
      );
    }
    return _prefs!;
  }

  // First Launch
  bool get isFirstLaunch =>
      _preferences.getBool(AppConstants.keyFirstLaunch) ?? true;

  Future<void> setFirstLaunchComplete() async {
    await _preferences.setBool(AppConstants.keyFirstLaunch, false);
    _notify();
  }

  // UI Language
  String get uiLanguage =>
      _preferences.getString(AppConstants.keyUiLanguage) ?? 'en';

  Future<void> setUiLanguage(String languageCode) async {
    await _preferences.setString(AppConstants.keyUiLanguage, languageCode);
    _notify();
  }

  // Audio Language
  String get audioLanguage =>
      _preferences.getString(AppConstants.keyAudioLanguage) ?? 'en';

  Future<void> setAudioLanguage(String languageCode) async {
    await _preferences.setString(AppConstants.keyAudioLanguage, languageCode);
    _notify();
  }

  // Itinerary
  List<String> get itinerary =>
      _preferences.getStringList(AppConstants.keyItinerary) ?? [];

  Future<void> addToItinerary(String siteId) async {
    final current = itinerary;
    if (!current.contains(siteId)) {
      current.add(siteId);
      await _preferences.setStringList(AppConstants.keyItinerary, current);
      _notify();
    }
  }

  Future<void> removeFromItinerary(String siteId) async {
    final current = itinerary;
    current.remove(siteId);
    await _preferences.setStringList(AppConstants.keyItinerary, current);
    _notify();
  }

  Future<void> clearItinerary() async {
    await _preferences.setStringList(AppConstants.keyItinerary, []);
    _notify();
  }

  bool isInItinerary(String siteId) => itinerary.contains(siteId);

  // Premium Offer
  bool get showPremiumOffer =>
      _preferences.getBool(AppConstants.keyShowPremiumOffer) ?? true;

  Future<void> setShowPremiumOffer(bool show) async {
    await _preferences.setBool(AppConstants.keyShowPremiumOffer, show);
    _notify();
  }

  // Premium status (demo only — no real billing integration). Scoped
  // per Firebase Auth UID so a purchase follows the user across
  // sign-out + sign-in on the same device, and never leaks to other
  // accounts on the same device.
  Map<String, bool> get premiumDemoByUser {
    final raw = _preferences.getString(AppConstants.keyPremiumDemoByUser);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v == true));
    } catch (_) {
      // Corrupt entry — treat as empty so a single bad write doesn't
      // permanently lock out the device from premium.
      return const {};
    }
  }

  bool isPremiumDemoFor(String userId) =>
      premiumDemoByUser[userId] ?? false;

  Future<void> setPremiumDemoFor(String userId, bool value) async {
    if (isPremiumDemoFor(userId) == value) return;
    final map = Map<String, bool>.from(premiumDemoByUser);
    if (value) {
      map[userId] = true;
    } else {
      map.remove(userId);
    }
    await _preferences.setString(
      AppConstants.keyPremiumDemoByUser,
      jsonEncode(map),
    );
    _notify();
  }

  // First-audio-played flag. Login / Register gates read this to
  // suppress the post-login value-prop screen for users who already
  // know the audio exists. Persists across sign-out by design — this
  // is a per-device flag, not a per-account flag.
  bool get audioPreviewedAtLeastOnce =>
      _preferences.getBool(AppConstants.keyAudioPreviewedAtLeastOnce) ?? false;

  Future<void> setAudioPreviewedAtLeastOnce(bool value) async {
    await _preferences.setBool(
      AppConstants.keyAudioPreviewedAtLeastOnce,
      value,
    );
    _notify();
  }

  // User ID
  String? get userId => _preferences.getString(AppConstants.keyUserId);

  Future<void> setUserId(String? id) async {
    if (id == null) {
      await _preferences.remove(AppConstants.keyUserId);
    } else {
      await _preferences.setString(AppConstants.keyUserId, id);
    }
    _notify();
  }

  // Is User Logged In (for skipping welcome screen)
  bool get isUserLoggedIn {
    final userId = _preferences.getString(AppConstants.keyUserId);
    return userId != null && userId.isNotEmpty;
  }

  Future<void> setUserLoggedIn(
    bool isLoggedIn, {
    String? userId,
    String? userRole,
  }) async {
    if (isLoggedIn && userId != null) {
      await _preferences.setString(AppConstants.keyUserId, userId);
      if (userRole != null) {
        await _preferences.setString('user_role', userRole);
      }
    } else {
      await _preferences.remove(AppConstants.keyUserId);
      await _preferences.remove('user_role');
    }
    _notify();
  }

  String? get savedUserRole => _preferences.getString('user_role');

  // Favorites
  List<String> get favorites =>
      _preferences.getStringList(AppConstants.keyFavorites) ?? [];

  Future<void> setFavorites(List<String> favoriteIds) async {
    await _preferences.setStringList(AppConstants.keyFavorites, favoriteIds);
    _notify();
  }

  Future<void> addFavorite(String siteId) async {
    final current = favorites;
    if (!current.contains(siteId)) {
      current.add(siteId);
      await _preferences.setStringList(AppConstants.keyFavorites, current);
      _notify();
    }
  }

  Future<void> removeFavorite(String siteId) async {
    final current = favorites;
    current.remove(siteId);
    await _preferences.setStringList(AppConstants.keyFavorites, current);
    _notify();
  }

  bool isFavorite(String siteId) => favorites.contains(siteId);

  // Clear all
  Future<void> clearAll() async {
    await _preferences.clear();
    _notify();
  }

  // Theme Mode ('light', 'dark', 'system'). Default to 'light'.
  String get themeMode =>
      _preferences.getString(AppConstants.keyThemeMode) ?? 'light';

  Future<void> setThemeMode(String mode) async {
    await _preferences.setString(AppConstants.keyThemeMode, mode);
    _notify();
  }

  // Arrival alerts. When true (the default) the navigation screen
  // surfaces an ArrivalOverlay modal when the user enters a site's
  // entry radius. When false the GPS-driven arrival detection is
  // suppressed — the map continues to update position, but no
  // modal pops up.
  bool get arrivalAlertsEnabled =>
      _preferences.getBool(AppConstants.keyArrivalAlertsEnabled) ?? true;

  Future<void> setArrivalAlertsEnabled(bool enabled) async {
    await _preferences.setBool(AppConstants.keyArrivalAlertsEnabled, enabled);
    _notify();
  }

  // --- PR-B Settings (read by Settings screen; consumers in detail/
  // navigation screens are follow-up work, gated on these getters) ---

  /// Arrival-detection radius in meters. Defaults to [defaultRadiusMeters]
  /// (30 m). The detail screen will use this to decide whether the user
  /// has "arrived" at a site.
  int get arrivalAlertsRadiusM =>
      _preferences.getInt(AppConstants.keyArrivalAlertsRadiusM) ??
      AppConstants.defaultRadiusMeters.round();

  Future<void> setArrivalAlertsRadiusM(int meters) async {
    await _preferences.setInt(AppConstants.keyArrivalAlertsRadiusM, meters);
    _notify();
  }


  /// Distance display units. 'metric' (m/km) or 'imperial' (ft/mi).
  /// Defaults to metric. Distance formatting helpers in [DistanceCalculator]
  /// (or wherever they're read) are gated on this in a follow-up PR.
  String get distanceUnits =>
      _preferences.getString(AppConstants.keyDistanceUnits) ?? 'metric';

  Future<void> setDistanceUnits(String units) async {
    await _preferences.setString(AppConstants.keyDistanceUnits, units);
    _notify();
  }

  /// Reduce-motion preference. v1 stores the flag; detail-screen
  /// [AnimatedSwitcher]s and the arrival pulse read it in a follow-up PR.
  bool get reduceMotion =>
      _preferences.getBool(AppConstants.keyReduceMotion) ?? false;

  Future<void> setReduceMotion(bool enabled) async {
    await _preferences.setBool(AppConstants.keyReduceMotion, enabled);
    _notify();
  }

  /// TTS playback-rate multiplier. Defaults to 1.0. Persisted as the
  /// string form of a double to keep SharedPreferences ergonomic.
  double get playbackSpeed {
    final raw = _preferences.getString(AppConstants.keyPlaybackSpeed);
    return double.tryParse(raw ?? '') ?? 1.0;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _preferences.setString(
      AppConstants.keyPlaybackSpeed,
      speed.toString(),
    );
    _notify();
  }

  /// Auto-play narration as soon as the user enters a site's arrival radius.
  /// Defaults to true — matches the in-app preview flow where the tour starts
  /// the moment you arrive. SiteDetailCubit reads this in a follow-up PR.
  bool get autoPlayOnArrival =>
      _preferences.getBool(AppConstants.keyAutoPlayOnArrival) ?? true;

  Future<void> setAutoPlayOnArrival(bool enabled) async {
    await _preferences.setBool(AppConstants.keyAutoPlayOnArrival, enabled);
    _notify();
  }
}

/// Thin `ChangeNotifier` subclass so [SharedPrefsService] can call
/// `notifySubscribers()` from its own setters (the protected
/// `notifyListeners` API can only be invoked from inside a
/// `ChangeNotifier` subclass).
class SharedPrefsChangeNotifier extends ChangeNotifier {
  void notifySubscribers() => notifyListeners();
}
