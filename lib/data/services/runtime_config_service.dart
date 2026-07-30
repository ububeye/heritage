import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Immutable snapshot of every runtime-config value the app exposes to
/// admins. Returned by [RuntimeConfigService.watch] and emitted once per
/// persistence write so [RuntimeConfigCubit] can `emit` a new state.
class RuntimeConfigSnapshot {
  const RuntimeConfigSnapshot({
    required this.freeAudioMaxSeconds,
    required this.orsApiKey,
    required this.maintenanceMode,
  });

  /// Default values for a fresh install — mirrors the keys in
  /// [AppConstants] (private defaults live here, not there, so the
  /// SharedPreferences keys stay the single point of documentation).
  factory RuntimeConfigSnapshot.initial() => const RuntimeConfigSnapshot(
        freeAudioMaxSeconds: 30,
        orsApiKey: '',
        maintenanceMode: false,
      );

  final int freeAudioMaxSeconds;
  final String orsApiKey;
  final bool maintenanceMode;

  RuntimeConfigSnapshot copyWith({
    int? freeAudioMaxSeconds,
    String? orsApiKey,
    bool? maintenanceMode,
  }) {
    return RuntimeConfigSnapshot(
      freeAudioMaxSeconds: freeAudioMaxSeconds ?? this.freeAudioMaxSeconds,
      orsApiKey: orsApiKey ?? this.orsApiKey,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RuntimeConfigSnapshot &&
      other.freeAudioMaxSeconds == freeAudioMaxSeconds &&
      other.orsApiKey == orsApiKey &&
      other.maintenanceMode == maintenanceMode;

  @override
  int get hashCode => Object.hash(
        freeAudioMaxSeconds,
        orsApiKey,
        maintenanceMode,
      );

  @override
  String toString() =>
      'RuntimeConfigSnapshot(seconds=$freeAudioMaxSeconds, '
      'orsApiKey=${orsApiKey.isEmpty ? '(empty)' : '(set)'}, '
      'maintenance=$maintenanceMode)';
}

/// Singleton over [SharedPreferences] that owns the three runtime-config
/// values admins can change without rebuilding the app:
///
///   * [freeAudioMaxSeconds] — free-tier narration preview length.
///   * [orsApiKey] — OpenRouteService API key. Empty string means the
///     OSRM demo is used instead.
///   * [maintenanceMode] — when true, the splash screen routes
///     non-admin users to a polite "we're updating" screen.
///
/// ## Why SharedPreferences (not Firestore)?
///
/// Mirrors the existing pattern in [SharedPrefsService] for `showPremiumOffer`,
/// `arrivalAlertsRadiusM`, etc. — no new infra, no security rules, no listener
/// wiring. Survives app restart. Trade-off: changes are device-local. Today
/// the admin model is single-device, so this is acceptable. If we later want
/// a multi-admin deployment where settings propagate, the migration is to
/// swap `_read` / `_write` here for Firestore-backed reads/writes; the public
/// API of this service stays the same.
///
/// ## Why a broadcast [Stream]?
///
/// [TtsService] and [RoutingService] are constructed outside the widget tree
/// (top-level locals in `app.dart`) and can't `BlocProvider.of`. They read
/// the values through the *service* directly. UI widgets need `BlocBuilder`
/// rebuilds when an admin changes a value; the cubit subscribes to
/// [watch] and re-emits on every persistence write. Same source of truth,
/// two consumers.
class RuntimeConfigService {
  RuntimeConfigService._(this._prefs) {
    _current = RuntimeConfigSnapshot(
      freeAudioMaxSeconds:
          _prefs.getInt(AppConstants.keyFreeAudioMaxSeconds) ?? 30,
      orsApiKey: _prefs.getString(AppConstants.keyOrsApiKey) ?? '',
      maintenanceMode:
          _prefs.getBool(AppConstants.keyMaintenanceMode) ?? false,
    );
  }

  static RuntimeConfigService? _instance;
  final SharedPreferences _prefs;

  /// Cached snapshot. Re-read from SharedPreferences on each `set*()` call
  /// (cheap — SharedPreferences keeps an in-memory map). The cache lets
  /// synchronous getters ([freeAudioMaxSeconds], etc.) stay synchronous.
  late RuntimeConfigSnapshot _current;

  /// Broadcast controller. One listener is the [RuntimeConfigCubit] for
  /// UI rebuilds; another may be a test. Multiple subscribers is fine —
  /// that's the whole point of broadcast.
  final StreamController<RuntimeConfigSnapshot> _controller =
      StreamController<RuntimeConfigSnapshot>.broadcast();

  /// Initialise the singleton. Must be awaited in `main.dart` before
  /// `runApp` — otherwise the first frame reads defaults from
  /// [RuntimeConfigSnapshot.initial] instead of persisted values.
  static Future<RuntimeConfigService> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = RuntimeConfigService._(prefs);
    return _instance!;
  }

  /// Access the singleton. Throws if [getInstance] hasn't run yet — this
  /// mirrors the [SharedPrefsService.instance] contract.
  static RuntimeConfigService get instance {
    if (_instance == null) {
      throw Exception(
        'RuntimeConfigService not initialized. '
        'Call RuntimeConfigService.getInstance() in main() first.',
      );
    }
    return _instance!;
  }

  // ── Plain getters (consumed by services outside the widget tree) ────

  int get freeAudioMaxSeconds => _current.freeAudioMaxSeconds;
  String get orsApiKey => _current.orsApiKey;
  bool get maintenanceMode => _current.maintenanceMode;

  // ── Stream (consumed by the cubit for UI rebuilds) ─────────────────

  /// Broadcast stream of the current snapshot. Emits once per [set*] call
  /// *after* the persistence write completes. The initial event is the
  /// persisted snapshot read at construction time.
  Stream<RuntimeConfigSnapshot> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  // ── Setters ─────────────────────────────────────────────────────────

  Future<void> setFreeAudioMaxSeconds(int seconds) async {
    final clamped = seconds < 5 ? 5 : seconds; // floor at 5 s — anything
    // shorter is just a click, not a preview
    await _prefs.setInt(AppConstants.keyFreeAudioMaxSeconds, clamped);
    _current = _current.copyWith(freeAudioMaxSeconds: clamped);
    _controller.add(_current);
  }

  Future<void> setOrsApiKey(String key) async {
    // Trim aggressively: an admin pasting a key with surrounding whitespace
    // (a frequent copy-paste artefact from password managers) silently
    // breaks the Authorization header.
    final trimmed = key.trim();
    await _prefs.setString(AppConstants.keyOrsApiKey, trimmed);
    _current = _current.copyWith(orsApiKey: trimmed);
    _controller.add(_current);
  }

  Future<void> setMaintenanceMode(bool enabled) async {
    await _prefs.setBool(AppConstants.keyMaintenanceMode, enabled);
    _current = _current.copyWith(maintenanceMode: enabled);
    _controller.add(_current);
  }

  /// Release the broadcast stream. Called from [RuntimeConfigCubit.close]
  /// — never call from app code, the singleton is process-lifetime.
  void dispose() {
    _controller.close();
  }
}
