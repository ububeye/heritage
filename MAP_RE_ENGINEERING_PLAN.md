# Map System Deep Re-Engineering — Implementation Plan

## Context

The existing map subsystem was already once re-engineered (see `MAP_SYSTEM_AUDIT_REPORT.md` dated 2026-08-16). Despite that commit, the user reports the experience is still poor:

- **Zooming has issues** — camera resets, fights user gestures, snaps back.
- **Navigation is not real** — the polyline is real OSRM GeoJSON, but the camera doesn't follow, the HUD is sparse, and arrival is single-fix.
- **Map is too simple** — no scale bar, no real compass, no off-route indicator, no selected-site animation.

Three audits just completed (map-subsystem inventory, docs-vs-code delta, test/build context) confirm:

1. The existing OSRM/foot routing chain is real and tested. The user's "navigation is not real" complaint is **not** about routing — it's about camera ownership, HUD quality, GPS smoothing, and arrival confirmation.
2. `MapController` and `LocationService` are leaked (no `dispose()` in `HeritageMap` or `NavigationScreenOpen`).
3. Camera ownership is implicit; multiple call sites move the camera without respecting user gestures.
4. Heading detection treats `pos.heading == 0.0` as "no fix" — wrong; 0 is North.
5. Arrival triggers on a single GPS fix inside the radius — no debounce.
6. Off-route threshold is 30 m hard-coded; docs claim 35 m.
7. `RoutingService` is widget-scoped; `RouteCacheService` is widget-scoped.
8. `NavigationStatus.completed` is dead code.
9. README/stale deps: `google_maps_flutter` and `flutter_polyline_points` declared in pubspec but not imported anywhere. README says `tile.openstreetmap.org` but code uses CARTO Voyager.
10. Pin-chip shadow in `_HeritagePin` is still inline (incomplete PR 4b migration).

Decisions confirmed with the user:
- **Routing engine**: keep OSRM public `foot` profile; ORS remains a key-gated fallback.
- **Tile provider**: keep CARTO Voyager.
- **Scope**: P0+P1+P2 (full pass).
- **Clustering**: none — document why (~20 sites).

The target is a polished, professional heritage-tourism navigation map that survives real use on a phone in Stone Town — pinch zoom feels right, the camera respects the user, GPS updates are smooth, walking routes follow the real pedestrian network, off-route is detected and recovered, arrival is reliable, and the visual story is more than "tiles + dots + line."

---

## Architecture After Re-Engineering

### Camera Ownership

Introduce a single source of truth for the camera. The widget does not own an explicit `MapController` field; instead it listens to a `MapCameraController` (a `ChangeNotifier` + `ValueListenable<CameraState>`) that owns the `MapController` and a `CameraMode` enum.

```dart
enum CameraMode {
  idle,                  // No special behavior.
  userInteracting,       // User is panning/zooming — do not steal the camera.
  followingLocation,     // Explore/SiteMap: track GPS but stay on free pan after gesture.
  followingNavigation,   // NavigationScreen: track GPS, animate camera, rotate on heading.
  selectingSite,         // HeritageMap.browse: animating to a selected site.
  fittingRoute,          // NavigationScreen: animating fitCamera to all route points.
}
```

#### Mode transitions

| From                      | Trigger                              | To                    |
|---------------------------|--------------------------------------|-----------------------|
| `idle` (any)              | User pan/zoom                        | `userInteracting`     |
| `idle`                    | `MapCameraController.followLocation()` | `followingLocation` |
| `followingLocation`       | User pan/zoom                        | `userInteracting`     |
| `followingNavigation`     | User pan/zoom                        | `userInteracting`     |
| `userInteracting`         | User taps "Re-center" / "Recenter"   | `following*`          |
| `selectingSite`           | Animation completes                  | `idle` / current mode |
| `fittingRoute`            | Animation completes                  | `followingNavigation` |
| `followingNavigation`     | User taps recenter once              | `followingNavigation` (re-orient) |
| `followingNavigation`     | User taps recenter twice (or long-press) | `userInteracting`  |

The "double-tap-to-leave-follow" pattern is industry-standard (Google Maps, Waze, Apple Maps). Implement by tracking `_lastRecenterTap` timestamp; second tap within 600 ms exits follow mode.

### State Flow

```
NavigationScreenOpen
   │
   ├─► Listens to NavigationCubit (status, currentPosition, errorCode)
   ├─► Listens to MapCameraController (cameraMode, plannedZoom, plannedCenter)
   ├─► Subscribes to UserPositionStream (raw GPS)
   │      │
   │      └─► GpsFilter.smooth() → filteredPosition
   │             │
   │             └─► screen reads filteredPosition; drives MapCameraController.followLocation()
   │
   ├─► Subscribes to RoutingService (route, distance, steps)
   │
   └─► PolylineSnap.projectPoint(filteredPosition, route) → offRoute?  → debounced re-route
```

### Provider chain (no change to engines)

```
FirestoreRouteCache (per-site, 30 days)
   ↓ miss
InMemoryRouteCache (per-(from,to), 30 min)
   ↓ miss
ORS if key provided, else OSRM (foot)
   ↓ any failure
Sanity-clip (maxRouteDistanceMeters = 8000 m)
   ↓ fail
RouteResult.fallback (straight line)
```

---

## Implementation — Ordered, Prioritized

### P0 — Critical bugs (must ship first)

**P0-1: Fix `MapController` lifecycle and `LocationService` leak.**
- File: `lib/ui/widgets/heritage_map.dart`. Add `dispose()` overriding `State.dispose`: `_mapController.dispose(); _locationService?.dispose(); super.dispose();`.
- File: `lib/ui/screens/navigation_screen_open.dart`. In existing `dispose()`, add `_mapController.dispose();` before `super.dispose()`.
- Why: avoids MapController and StreamController leaks on screen pop.

**P0-2: Fix camera ownership — introduce `MapCameraController`.**
- New file: `lib/state/map/map_camera_controller.dart`. Class extending `ChangeNotifier` with fields:
  - `MapController mapController`
  - `CameraMode _mode = CameraMode.idle`
  - `LatLng? _plannedCenter`, `double? _plannedZoom`
  - `String? _suppressGestureUntil` (a tick timestamp during `_mapController.move()` calls so user-gesture detection doesn't trip)
  - API: `setMode(CameraMode)`, `requestFollow(LatLng, {double? zoom})`, `requestFit(List<LatLng>, {EdgeInsets? padding})`, `requestSelectSite(LatLng, {double? zoom})`, `markUserGesture()`, `recenter()`, `dispose()`.
- New file: `lib/ui/widgets/map/map_mode_listener.dart`. Wraps `FlutterMap.options.onPositionChanged` and feeds `markUserGesture()` into the controller.
- `HeritageMap` and `NavigationScreenOpen` consume the controller via `Provider`/`InheritedNotifier` (BlocProvider from app level so it survives route changes).
- All existing `_mapController.move/fitCamera/rotate` callsites are replaced with explicit controller methods. No direct controller access from widget code.
- Replaces the local `NavigationCameraMode { following, free }` enum at `lib/ui/screens/navigation_screen_open.dart:40-46`.
- Why: stops the camera from fighting the user; clarifies ownership.

**P0-3: Fix zoom reset on selection / bottom-sheet.**
- When `_SitePreviewCard` opens on `HeritageMap.browse`, it must NOT call any camera method. Selection should only request `MapCameraController.requestSelectSite(site.position, zoom: 16.5)` once, with a debounce so a re-selection doesn't double-fire.
- The maneuver card top-padding in `_fitInitial` (`EdgeInsets.fromLTRB(60, 160, 60, 220)`) uses a fixed 160; replace with a measurement key derived from the actual maneuver card height when shown.
- File: `lib/ui/screens/navigation_screen_open.dart` `_fitInitial` line 309.

**P0-4: Fix heading detection.**
- File: `lib/core/utils/heading_source.dart` (new). Class with `double? current`, `void onPosition(Position pos)`, `void onGpsDerived({required LatLng prev, required LatLng curr, required Duration dt})`.
- Strategy:
  1. If `pos.headingAccuracy > 0` and `pos.headingAccuracy < 30°` → use `pos.heading` directly.
  2. Else if previous fix was within 5 s → compute bearing from two consecutive fixes, store as a fallback.
  3. Apply a 5° EMA hysteresis to avoid jitter.
- `NavigationScreenOpen._animateCameraTo` uses `HeadingSource.current` instead of `pos.heading`. Drop the `pos.heading != 0.0` guard.
- Why: `0` is a valid heading; some devices always report `0` from stationary fixes; rotation no longer gets stuck.

**P0-5: Fix arrival detection with debounce.**
- File: `lib/blocs/navigation/navigation_cubit.dart`. Replace single-check `_hasArrived` with:
  - `_consecutiveInsideRadius = 0`
  - `_arrivalConfirmCount = SharedPrefsService.instance.arrivalAlertsRadiusM >= 50 ? 3 : 2` (configurable)
  - On each GPS fix inside `_entryRadiusM`, increment; when >= count, fire `arrived` state.
  - Outside → reset to 0.
- Add `static const int defaultArrivalConfirmCount = 2;` to `AppConstants`.
- Why: noisy GPS can drop the user briefly outside the radius and back in; without debounce, the arrival overlay flickers.

**P0-6: Centralize off-route threshold and add hysteresis.**
- File: `lib/core/constants/app_constants.dart`. Add `static const double offRouteThresholdMeters = 30.0;`. Remove the constant at `lib/core/utils/polyline_snap.dart:47` and have `PolylineSnap.defaultOffRouteThresholdMeters` reference `AppConstants.offRouteThresholdMeters`.
- Add lightweight hysteresis in `PolylineSnap.isOffRoute`: don't return `true` until cross-track has been > threshold for at least 2 consecutive fixes within 8 s. Implement as a `PolylineSnap.deviationTracker({List<bool> history, DateTime lastSampleAt})` helper.
- File: `lib/core/utils/polyline_snap.dart` — add the helper, keep `defaultOffRouteThresholdMeters` as a public alias for `AppConstants.offRouteThresholdMeters` for backward compatibility.

**P0-7: Make the visual navigation experience "real".**
- The route is already real OSRM GeoJSON. The user perceives it as fake because:
  - Camera doesn't gently follow the user with smooth easing.
  - Destination marker doesn't snap to the actual building entrance.
  - HUD is sparse (one card, one chip).
  - Off-route is silent.
- Fixes (covered in P1 / P2 below): animated camera follow at adaptive zoom; destination snap to nearest polyline vertex (already done at `navigation_screen_open.dart:184-187`); richer HUD; off-route banner; heading rotation.

**P0-8: App-scoped services.**
- `RouteCacheService` becomes `BlocProvider<RouteCacheService>` at app level (in `app.dart`), not widget-scoped. `RoutingService` similarly app-scoped.
- `LocationService` stays a singleton via `SharedPrefsService.instance` pattern (or promoted to a `BlocProvider`).
- `MapCameraController` is `BlocProvider<MapCameraController>` at app level so screen-to-screen transitions keep camera state coherent.
- Why: two concurrent navigations would each get their own cache today; routing service is created per widget.

---

### P1 — Navigation behavior

**P1-1: Off-route detection + hysteresis.** Already covered in P0-6.

**P1-2: Off-route UI feedback.**
- New file: `lib/ui/widgets/map/off_route_banner.dart`. Shows a non-blocking banner "Recalculating route…" while `_isRerouting` is true (already at `navigation_screen_open.dart:106`).
- Embedded inside `NavigationScreenOpen` between the maneuver card and the bottom card.

**P1-3: Reroute telemetry.**
- Add `void Function(String event, Map<String, Object?>)? telemetry` to `RoutingService` (optional constructor arg).
- Emit `'routing_reroute'` with `{siteId, deviation_m, reason, latency_ms, result.provider}` on reroute.
- For now, log to `debugPrint` (production hook can be added later).

**P1-4: Reroute suppression within arrival radius.**
- In `NavigationScreenOpen._fetchRoute(isReroute: true)`, skip the reroute if `distanceToSite < SharedPrefsService.instance.arrivalAlertsRadiusM * 1.5`. Prevents tiny GPS wobble near the destination from triggering a fresh route.

**P1-5: GPS smoothing.**
- New file: `lib/core/utils/gps_filter.dart`. Class `GpsFilter` with:
  - `LatLng? filter(Position pos)` — exponential moving average weighted by `pos.accuracy`.
  - `alpha = 0.4` if `pos.accuracy < 10 m`, `0.2` if `pos.accuracy < 30 m`, else `0.1`.
  - Buffer of last 5 positions; rejects a fix more than 3 σ from the EMA.
- New file: `lib/data/services/heading_service.dart` (lightweight wrapper around `HeadingSource` + GPS-derived fallback).
- `NavigationScreenOpen` consumes `GpsFilter.filter(...)` and uses the filtered `LatLng` for camera moves and `PolylineSnap.projectPoint(...)`.

**P1-6: Maneuver UX.**
- File: `lib/ui/screens/navigation_screen_open.dart` `_buildTopManeuverCard`. Already uses `RouteStep.localizedDescription` and `ManeuverIcon.forManeuver`. Verify both renderers display correctly when `step.name.isEmpty` (use `tr('continue_straight')`). Add test coverage if missing.
- File: `test/routing_steps_test.dart` already covers `localizedDescription` for: turn with street name, continue without modifier, modifier-only, depart, arrive. Add a snapshot for "continue straight" case.

**P1-7: Remove dead `NavigationStatus.completed`.**
- File: `lib/data/models/navigation_state.dart`. Remove `completed` enum value.
- File: `lib/blocs/navigation/navigation_cubit.dart`. No callers emit it today; double-check by grep.

**P1-8: Fixed provider capture to prevent flicker.**
- File: `lib/data/services/routing_service.dart` line 348. Capture `RuntimeConfigService.instance.orsApiKey` at service construction time (or at `app.dart` startup), not per call. Avoids `provider` field in `RouteResult` flickering if the key is changed mid-session.

**P1-9: Provider-chain telemetry.**
- File: `lib/data/services/routing_service.dart`. Add `static const _RoutingProvider osrmDemo` retry on 5xx (one retry with 250 ms backoff) before falling through to fallback. Add to `RoutingService` docs.

---

### P2 — Visual refinement

**P2-1: Add scale bar.**
- New file: `lib/ui/widgets/map/scale_bar.dart`. Simple `Container` rendered in the bottom-left of `FlutterMap` overlay. Uses `camera.zoom` and the device pixel ratio to compute a metric/imperial scale. Reads `SharedPrefsService.instance.distanceUnits` for unit choice.
- Place in both `HeritageMap` and `NavigationScreenOpen`.

**P2-2: Add true compass overlay.**
- New file: `lib/ui/widgets/map/compass_overlay.dart`. Circular widget showing the current `HeadingSource.current` and a north pointer. Visible only when `CameraMode == followingNavigation`. Hidden when `_headingLocked == false` (user has rotated the map).

**P2-3: Off-route polyline color pulse.**
- File: `lib/ui/screens/navigation_screen_open.dart` `_buildMap`. When `isOffRoute == true`, render the route polyline with an amber tint (`AppSemanticColors.warningContainer`) instead of the default `mapRoute`. Reverts to default after reroute confirms.

**P2-4: Replace inline BoxShadow in `_HeritagePin` with token.**
- File: `lib/ui/widgets/heritage_map.dart` lines 530-536. Replace inline `BoxShadow` with `AppShadows.mapPinFor(context)`. Completes the deferred shadow sites migration.

**P2-5: Selected marker animation.**
- File: `lib/ui/widgets/map/selected_site_marker.dart` (new). Extracted from `HeritageMap._HeritagePin`. When `selectedSite.id == site.id`, the pin pulses (slight scale + soft shadow) using `AnimationController` + `Tween<double>(1.0, 1.08)`.
- Camera animates to `site.position` with `Curves.easeInOut` over 400 ms via `MapCameraController.requestSelectSite(...)`.

**P2-6: SiteMapScreen "Show route" toggle.**
- File: `lib/ui/screens/site_map_screen.dart`. Add a `SwitchListTile` in the AppBar that, when enabled, fetches a route from current GPS to the site and renders the polyline layer + ETA chip. Reuses `RoutingService`. Doesn't enter navigation mode.

**P2-7: `MapProviderCubit` for runtime provider switching.**
- New file: `lib/blocs/runtime_config/map_provider_cubit.dart`. Reads/writes `SharedPrefsService.instance.mapProvider`. If a key is provided via `RuntimeConfigService.orsApiKey`, the cubit exposes `available: ['open', 'openRouteService']`; otherwise `['open']`. Wired to a Settings tile.
- Add Settings tile "Routing engine" in `lib/ui/screens/settings_screen.dart` (or admin panel) that lets the operator pick the provider.

**P2-8: "Clear map cache" settings tile.**
- New tile in Settings/Admin panel. `TileCacheService.getTotalSizeBytes()` shows disk usage; "Clear" button calls `TileCacheService.clear()` and confirms with a snackbar.

**P2-9: Update README.**
- File: `README.md`. Maps section: replace `tile.openstreetmap.org` with `a.basemaps.cartocdn.com/rastertiles/voyager/`. Add `userAgentPackageName: 'com.stonetown.guide'`. Add a brief Navigation section noting OSRM foot + ORS fallback.

**P2-10: Drop dead dependencies.**
- File: `pubspec.yaml`. Remove `google_maps_flutter`, `flutter_polyline_points`. Run `flutter pub get` to confirm no imports break.

**P2-11: Update MAP_SYSTEM_AUDIT_REPORT.md.**
- Refresh with the new architecture, the new `MapCameraController` flow, the resolved GPS smoothing, the visual HUD, the documented "no clustering" decision, and the offline behavior matrix.

**P2-12: Pin-chip shadow migration completion.**
- Already covered in P2-4.

---

## New Files to Create

| File | Purpose |
|---|---|
| `lib/state/map/map_camera_controller.dart` | Camera ownership + `CameraMode` enum |
| `lib/ui/widgets/map/map_mode_listener.dart` | Listens to `onPositionChanged` for `markUserGesture` |
| `lib/core/utils/heading_source.dart` | Heading detection with EMA + GPS fallback |
| `lib/data/services/heading_service.dart` | Wrapper for `HeadingSource` |
| `lib/core/utils/gps_filter.dart` | EMA filter weighted by GPS accuracy + 3σ rejection |
| `lib/ui/widgets/map/compass_overlay.dart` | Compass widget |
| `lib/ui/widgets/map/scale_bar.dart` | Scale bar widget |
| `lib/ui/widgets/map/off_route_banner.dart` | "Recalculating route…" banner |
| `lib/ui/widgets/map/navigation_hud.dart` | Combined maneuver card + ETA + progress |
| `lib/ui/widgets/map/destination_marker.dart` | Extracted destination marker |
| `lib/ui/widgets/map/user_marker.dart` | Extracted user marker (currently in `navigation_screen_open.dart:1278-1351`) |
| `lib/ui/widgets/map/route_polyline_layer.dart` | Extracted polyline + shadow + off-route tint |
| `lib/ui/widgets/map/selected_site_marker.dart` | Extracted selected marker with pulse |
| `lib/ui/widgets/map/site_marker.dart` | Extracted `_HeritagePin` minus the selected-state pulse |
| `lib/blocs/runtime_config/map_provider_cubit.dart` | Runtime provider switching |
| `test/blocs/navigation_cubit_test.dart` | NavigationCubit tests with hand-written fakes |
| `test/gps_filter_test.dart` | EMA + 3σ rejection |
| `test/polyline_snap_hysteresis_test.dart` | Hysteresis logic |
| `test/heading_source_test.dart` | HeadingSource strategy |
| `test/navigation_screen_open_widget_test.dart` | Widget test for camera mode + recenter |
| `test/heritage_map_widget_test.dart` | Widget test for marker selection + camera ownership |
| `test/routing_service_retry_test.dart` | 5xx retry with backoff |
| `test/routing_service_telemetry_test.dart` | Telemetry events on reroute |
| `test/routing_service_reroute_suppression_test.dart` | Suppression within arrival radius |

## Files to Modify (representative)

| File | Changes |
|---|---|
| `lib/ui/widgets/heritage_map.dart` | `dispose()`; split into `_SitePin`, `_SitePreviewCard`, `selectedSiteMarker`; use `MapCameraController`; replace inline shadow with `AppShadows.mapPinFor(context)`; clamp via `pickerCameraBounds` |
| `lib/ui/screens/navigation_screen_open.dart` | `MapController` dispose; replace `NavigationCameraMode` with `MapCameraController`; use `GpsFilter`; use `HeadingSource`; arrival debounce; refactor markers into widgets; add scale bar, compass, off-route banner |
| `lib/ui/screens/site_map_screen.dart` | Add "Show route" toggle; integrate `MapCameraController` |
| `lib/screens/explore_screen.dart` | Use `MapCameraController` for `selectingSite` mode |
| `lib/ui/screens/admin/admin_add_site_screen.dart`, `admin_edit_site_screen.dart` | Defensive clamp; integrate `MapCameraController` |
| `lib/blocs/navigation/navigation_cubit.dart` | Arrival debounce; remove `completed`; add `recalculatingRoute` flag |
| `lib/blocs/navigation/navigation_state.dart` | Wrapper update |
| `lib/data/models/navigation_state.dart` | Remove `completed`; add `recalculatingRoute` |
| `lib/data/services/routing_service.dart` | Capture provider chain at startup; 5xx retry; telemetry hook |
| `lib/data/services/route_cache_service.dart` | Document app-scope usage |
| `lib/data/services/location_service.dart` | Confirm `dispose()` idempotent; clarify scope |
| `lib/core/utils/polyline_snap.dart` | Reference `AppConstants.offRouteThresholdMeters`; add hysteresis helper; fix single-vertex segmentIndex = -1 |
| `lib/core/constants/app_constants.dart` | Add `offRouteThresholdMeters`, `defaultArrivalConfirmCount`, `gpsSmoothingAlpha`, `routingRetryDelay` |
| `pubspec.yaml` | Drop `google_maps_flutter`, `flutter_polyline_points` |
| `README.md` | Update Maps section |
| `MAP_SYSTEM_AUDIT_REPORT.md` | Refresh with new architecture |

## Reused Existing Utilities

- `PolylineSnap.snapToPolyline`, `PolylineSnap.projectPoint` — keep, harden.
- `DistanceCalculator.calculateDistance`, `formatDistance`, `estimateWalkingTime` — keep.
- `AppShadows.mapPinFor` — finish migrating.
- `TileCacheService.instance.tileProvider()` — keep, but ensure `bootstrap()` is called in `main.dart` (already done).
- `UngujaBounds` / `StoneTownBounds` — no change to logic; constants are reused.
- `SharedPrefsService.instance.arrivalAlertsRadiusM`, `arrivalAlertsEnabled`, `distanceUnits`, `reduceMotion`, `autoPlayOnArrival` — keep reading directly from the service.
- `RoutingService` provider chain — keep OSRM primary, ORS key-gated.
- Hand-written fake pattern (no `mockito` / `mocktail`) — keep for new tests.

---

## Offline Behavior Matrix

| Behavior | ONLINE | OFFLINE CACHE | OFFLINE ROUTING | NOT AVAILABLE OFFLINE |
|---|---|---|---|---|
| View map tiles | ✓ | ✓ (cached on disk) | ✓ | |
| Browse heritage sites | ✓ | ✓ | ✓ | |
| View site details | ✓ | ✓ | ✓ | |
| GPS position | ✓ | ✓ | ✓ | |
| Walking route | ✓ (OSRM demo) | ✓ (cached route in Firestore 30 d) | ✗ (no local routing engine) | ✗ |
| Turn-by-turn instructions | ✓ | ✓ (cached) | ✓ (cached) | |
| Off-route recalculation | ✓ | ✗ (no network → suppress) | ✗ | ✗ |
| Voice turn-by-turn | ✗ (no TTS hook today) | ✗ | ✗ | ✗ |
| Background navigation | ✗ (no AndroidManifest permission) | ✗ | ✗ | ✗ |

Document this matrix explicitly in `MAP_SYSTEM_AUDIT_REPORT.md`.

---

## PR Breakdown (incremental, ship green per commit)

- **PR A**: Drop dead deps (`google_maps_flutter`, `flutter_polyline_points`) from `pubspec.yaml`; fix `MapController`/`LocationService` lifecycle in `HeritageMap` and `NavigationScreenOpen`; update README. Pure mechanical. **No behavior change.**
- **PR B**: App-scoped `RouteCacheService` + `RoutingService` via `BlocProvider`. Update `app.dart` and `NavigationScreenOpen`. **No behavior change at runtime.**
- **PR C**: Introduce `MapCameraController` + `CameraMode` enum. Refactor `NavigationScreenOpen` to use it. Behavior should be identical at the surface.
- **PR D**: Refactor `HeritageMap` to use `MapCameraController`. Split `_HeritagePin` into `SiteMarker` + `SelectedSiteMarker`. Replace inline shadow with `AppShadows.mapPinFor`.
- **PR E**: Off-route hysteresis (centralized threshold, dev helper). Off-route banner. Polyline amber tint.
- **PR F**: Add `GpsFilter` and `HeadingSource`. Wire into `NavigationScreenOpen`. Remove `pos.heading != 0.0` guard.
- **PR G**: Arrival debounce. Reroute suppression near destination. Reroute telemetry.
- **PR H**: Visual refinement — scale bar, compass overlay, navigation HUD redesign, selected-site pulse, "Show route" on SiteMapScreen.
- **PR I**: `MapProviderCubit` + Settings tile; "Clear map cache" tile; README + `MAP_SYSTEM_AUDIT_REPORT.md` refresh.
- **PR J**: Tests — `NavigationCubit`, widgets, telemetry, retry, suppression.

Each PR should keep `flutter analyze` clean and `flutter test` green.

---

## Verification

After each PR:
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze` (must be 0 issues)
- `flutter test` (all existing + new tests must pass)
- `flutter build apk --debug` (must succeed)

Manual smoke (post-PR C, mandatory before merge):
- Pinch zoom in/out at all elevations.
- Double-tap zoom.
- Button zoom.
- Zoom near Stone Town / Unguja bounds.
- Zoom at min and max zoom.
- Zoom while GPS is active.
- Zoom after selecting a marker.
- Zoom during navigation.
- Zoom after recenter.
- Pan while following — should switch to `userInteracting`.
- Pan near island edge — should clamp.

Manual smoke (post-PR F):
- Walk a real route (or feed mock positions through `NavigationCubit`) — verify smooth follow.
- Walk off-route — verify off-route banner appears, reroute fires, banner clears.
- Walk to destination — verify arrival detected reliably (no flicker with one bad fix).

Lifecycle smoke:
- Explore → Detail → Map → Navigation → Back → Explore. No leaked controllers, no stale subscriptions.
- Navigation → Background → Foreground. No crash. Camera does not jump.
- Repeatedly open/close the map. No slow UI.

---

## Remaining Limitations (to be honest about in the report)

- **No marker clustering**. Documented; ~20 sites doesn't justify it.
- **No background navigation**. AndroidManifest has no `ACCESS_BACKGROUND_LOCATION`. Out of scope.
- **No voice turn-by-turn prompts**. No TTS hook today; visual-only.
- **No self-hosted tile server**. CARTO is acceptable for this app's volume.
- **No polygon-shaped bounds**. Rectangular boxes are sufficient for Stone Town.
- **No true offline routing**. We can render cached routes offline; fresh routes still need OSRM. Document this honestly.
- **Cache persistence is in Firestore**. If the user is offline and has never visited a site, the route is unavailable. Mitigated by the 30-day in-memory cache within a session.
- **No telemetry sink**. Today logging is `debugPrint` only. Hook is in place for future analytics.
- **No site-entry-point support yet**. `SiteModel` could carry an `entryPointLat/Lng` distinct from its centroid, but doesn't today. When added, `RoutingService` and `PolylineSnap.snapToPolyline` will snap to the entry point instead of the centroid.

---

## Acceptance Criteria

- ✓ Zoom is smooth and predictable; user gestures are respected.
- ✓ GPS does not fight the user; follow mode is opt-in via a visible Re-center control.
- ✓ Markers render correctly with category styling, selected pulse, and shadows.
- ✓ Map looks professional (scale bar, compass, banner, refined HUD).
- ✓ Navigation follows actual walkable paths via OSRM `foot` profile.
- ✓ Turn-by-turn instructions render from `RouteStep.localizedDescription`.
- ✓ Off-route is detected (hysteresis), banner is shown, reroute fires, banner clears.
- ✓ Arrival is debounced (2–3 consecutive fixes inside radius).
- ✓ Route is cached (in-memory 30 min + Firestore 30 days).
- ✓ Old routes do not leak into new sessions (request id + cubit `_sessionId`).
- ✓ Map lifecycle does not leak controllers or subscriptions.
- ✓ Admin location selection is precise (clamped to picker bounds, tap + drag).
- ✓ Offline behavior is honestly documented.
- ✓ OpenStreetMap / CARTO attribution is correct.
- ✓ Implementation remains free / open-source.
- ✓ `flutter analyze` is clean; `flutter test` is green; `flutter build apk --debug` succeeds.
- ✓ `MAP_SYSTEM_AUDIT_REPORT.md` reflects the new architecture and the offline matrix.
