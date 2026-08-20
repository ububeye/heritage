import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Explicit camera ownership modes for the map subsystem.
///
/// The map has many potential camera controllers: user gestures, GPS
/// tracking, recenter button, marker selection, route fitting, navigation
/// progress, and bottom-sheet interactions. Without an explicit mode, these
/// fight each other — GPS snaps the camera back when the user is exploring,
/// markers reset zoom on selection, etc.
///
/// `MapCameraController` is the single source of truth. Widgets request
/// transitions (e.g. "follow the user", "select a site", "re-center") and
/// the controller arbitrates.
enum CameraMode {
  /// No special behaviour. The camera is free to do whatever the user asks.
  idle,

  /// The user is actively panning or pinching. The camera MUST NOT be
  /// moved by any background source (GPS, route updates, etc.) until the
  /// user explicitly asks for follow mode again.
  userInteracting,

  /// The map is tracking the user's GPS position but does not rotate
  /// with heading. Used by the explore / single-site maps.
  followingLocation,

  /// The map is tracking the user's GPS position, with adaptive zoom and
  /// optional heading rotation. Used by the navigation screen.
  followingNavigation,

  /// The map is animating to a selected site. Once the animation
  /// completes, the mode falls back to whatever was active before.
  selectingSite,

  /// The map is animating a `fitCamera` (e.g. show the whole route on
  /// arrival). Once complete, falls back to [followingNavigation] if
  /// applicable, otherwise [idle].
  fittingRoute,
}

/// Snapshot of the camera state, exposed by [MapCameraController] for
/// widgets that only need to read the latest state.
@immutable
class MapCameraState {
  const MapCameraState({
    required this.mode,
    this.suppressGestureUntil,
  });
  final CameraMode mode;

  /// Wall-clock time until which programmatic camera moves should NOT
  /// trigger the user-gesture detector. Set after every controller-driven
  /// move so the map's own `onPositionChanged` callback doesn't escalate
  /// the mode to [CameraMode.userInteracting] mid-animation.
  final DateTime? suppressGestureUntil;

  MapCameraState copyWith({
    CameraMode? mode,
    DateTime? suppressGestureUntil,
    bool clearSuppressGesture = false,
  }) {
    return MapCameraState(
      mode: mode ?? this.mode,
      suppressGestureUntil: clearSuppressGesture
          ? null
          : (suppressGestureUntil ?? this.suppressGestureUntil),
    );
  }
}

/// Owns the [MapController] and the [CameraMode] for the map subsystem.
///
/// Widgets don't directly manipulate the `MapController` for camera moves.
/// All camera operations go through this controller: follow, recenter,
/// select, fit, gestural pause, etc. This is the single arbiter that
/// prevents the GPS / navigation / selection code from fighting the user.
///
/// Lifecycle: the controller is created once at app start (via
/// `BlocProvider` at the root of the app) and `dispose()`d only when the
/// app exits. This lets multiple map screens share the same camera state
/// across navigation transitions.
class MapCameraController extends ChangeNotifier {
  MapCameraController({MapController? mapController})
      : mapController = mapController ?? MapController();

  /// The underlying map controller. Widgets that need to read the current
  /// camera (e.g. scale bar) can use this, but should NEVER call
  /// `move`, `fitCamera`, `rotate` directly on it. Always go through the
  /// controller methods below.
  final MapController mapController;

  CameraMode _mode = CameraMode.idle;
  CameraMode get mode => _mode;

  /// The mode that was active before a programmatic animation started
  /// (e.g. [requestSelectSite]). When the animation completes, the mode
  /// falls back to this value.
  CameraMode _pendingRestoreMode = CameraMode.idle;
  CameraMode get pendingRestoreMode => _pendingRestoreMode;

  /// Sticky-gesture timestamp. When a user-initiated gesture is detected
  /// (via the widget's `onPositionChanged`), the controller switches to
  /// [CameraMode.userInteracting] and remembers when the gesture started.
  DateTime? _userGestureAt;

  /// The most recent centre the controller was asked to follow or focus.
  LatLng? _plannedCenter;
  LatLng? get plannedCenter => _plannedCenter;

  double? _plannedZoom;
  double? get plannedZoom => _plannedZoom;

  DateTime? _suppressGestureUntil;

  /// Switch to a specific mode without moving the camera. Use this for
  /// state transitions that should not animate (e.g. entering free mode
  /// when the user starts a gesture).
  void setMode(CameraMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode != CameraMode.selectingSite && mode != CameraMode.fittingRoute) {
      _pendingRestoreMode = mode;
    }
    notifyListeners();
  }

  /// Mark that the user has just touched/pinched the map. Switches the
  /// mode to [CameraMode.userInteracting] if we were in a follow mode.
  ///
  /// This is called by the widget's `onPositionChanged` callback when
  /// `hasGesture == true`.
  void markUserGesture() {
    if (_mode == CameraMode.userInteracting) return;
    _userGestureAt = DateTime.now();
    _mode = CameraMode.userInteracting;
    notifyListeners();
  }

  /// Is the controller currently inside a programmatic animation where
  /// the user's `onPositionChanged` should be ignored?
  bool get isSuppressingGesture {
    final until = _suppressGestureUntil;
    if (until == null) return false;
    final suppressed = DateTime.now().isBefore(until);
    if (!suppressed) {
      _suppressGestureUntil = null;
    }
    return suppressed;
  }

  /// True if the user has gestured within the last [Duration]. Used by
  /// the widget to decide whether to escalate to follow mode on a
  /// recenter tap.
  bool isGestureRecent([Duration window = const Duration(seconds: 1)]) {
    final at = _userGestureAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < window;
  }

  /// Request the camera to follow the user's GPS position. The widget is
  /// responsible for calling this on each meaningful GPS update. The
  /// controller does not subscribe to GPS itself — the widget already has
  /// the cubit and the position stream.
  void requestFollowLocation(LatLng target, {double? zoom, double? rotation}) {
    if (_mode == CameraMode.userInteracting) return;
    _mode = CameraMode.followingLocation;
    _plannedCenter = target;
    _plannedZoom = zoom;
    _moveInternal(target, zoom: zoom, rotation: rotation);
    notifyListeners();
  }

  /// Request the camera to follow the user with navigation-specific
  /// behaviour (adaptive zoom, heading rotation). Same as
  /// [requestFollowLocation] but tagged differently so the widget can
  /// render the navigation HUD.
  void requestFollowNavigation(
    LatLng target, {
    double? zoom,
    double? rotation,
  }) {
    if (_mode == CameraMode.userInteracting) return;
    _plannedCenter = target;
    _plannedZoom = zoom;
    if (_mode != CameraMode.followingNavigation) {
      _mode = CameraMode.followingNavigation;
      notifyListeners();
    }
    _moveInternal(target, zoom: zoom, rotation: rotation);
  }

  /// Request the camera to animate to a selected site.
  void requestSelectSite(LatLng site, {double? zoom}) {
    _pendingRestoreMode = _mode == CameraMode.userInteracting
        ? CameraMode.userInteracting
        : _mode;
    _mode = CameraMode.selectingSite;
    _plannedCenter = site;
    _plannedZoom = zoom;
    _moveInternal(site, zoom: zoom);
    _scheduleModeRestore();
    notifyListeners();
  }

  /// Request a `fitCamera` to encompass all points. The widget provides
  /// the actual `fitCamera` call; the controller arbitrates the mode.
  void requestFit(List<LatLng> points, {EdgeInsets? padding}) {
    if (points.length < 2) return;
    _pendingRestoreMode = _mode;
    _mode = CameraMode.fittingRoute;
    _suppress(duration: const Duration(milliseconds: 120));
    _scheduleModeRestore();
    notifyListeners();
  }

  /// Re-enter follow mode. Use this for the "Re-center" FAB.
  void recenter() {
    _mode = _pendingRestoreMode == CameraMode.userInteracting
        ? CameraMode.followingLocation
        : _pendingRestoreMode;
    _userGestureAt = null;
    notifyListeners();
  }

  void _moveInternal(LatLng target, {double? zoom, double? rotation}) {
    _suppress();
    final camera = mapController.camera;
    if (zoom != null) {
      if (rotation != null) {
        mapController.moveAndRotate(target, zoom, rotation);
      } else {
        mapController.move(target, zoom);
      }
    } else {
      if (rotation != null) {
        mapController.moveAndRotate(target, camera.zoom, rotation);
      } else {
        mapController.move(target, camera.zoom);
      }
    }
  }

  /// Internal helper: bumps the suppress-gesture window so the next
  /// ~50 ms of `onPositionChanged` from the map is ignored.
  void _suppress({Duration duration = const Duration(milliseconds: 60)}) {
    _suppressGestureUntil = DateTime.now().add(duration);
  }

  /// Cached timer used to fall back from a transient animation mode
  /// ([CameraMode.selectingSite] / [CameraMode.fittingRoute]) to the
  /// mode that was active before.
  void _scheduleModeRestore() {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (_mode == CameraMode.selectingSite ||
          _mode == CameraMode.fittingRoute) {
        _mode = _pendingRestoreMode;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  /// Lookup a [MapCameraController] from the closest [MapCameraScope]
  /// ancestor. Returns `null` if no scope is in scope, in which case the
  /// caller should fall back to creating its own private controller.
  static MapCameraController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MapCameraScope>();
    return scope?.controller;
  }

  /// Convenience for callers that require a controller and want to
  /// throw if none is provided.
  static MapCameraController of(BuildContext context) {
    final c = maybeOf(context);
    if (c == null) {
      throw FlutterError(
        'MapCameraController.of() called from a context that does not '
        'contain a MapCameraScope. Wrap your app with MapCameraScope '
        'or use .maybeOf() and create a controller locally.',
      );
    }
    return c;
  }
}

/// Inherited widget that exposes a [MapCameraController] to descendants.
/// Wrap the navigation map tree with a [MapCameraScope] so all maps
/// share the same controller.
class MapCameraScope extends InheritedNotifier<MapCameraController> {
  const MapCameraScope({
    super.key,
    required MapCameraController controller,
    required super.child,
  }) : super(notifier: controller);

  MapCameraController get controller => notifier!;
}
