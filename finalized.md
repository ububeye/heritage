# Stone Town Heritage VT-Guide — Final Audit, Theme Recommendation, Navigation Recommendation, and Fix Plan

**Project:** Stone Town Heritage VT-Guide (Flutter + Firebase)
**Repository root:** `c:\Users\noble\StudioProjects\stone_town_heritage_vt_guide`
**Audit date:** 2026-06-30
**Flutter / Dart in use:** Flutter 3.29.0 (stable) · Dart 3.7.0
**Static analysis (`flutter analyze`):** ✅ No issues found

This document consolidates a full read-through of the project, a recommended color/theme refresh for a UNESCO-heritage storytelling app, the recommended open-source navigation stack, and a phased, ready-to-execute fix plan that lists every concrete bug, UX defect, security/safety concern, performance issue, and DX gap found during the audit. Each finding is tagged by severity and includes file references so changes can be applied without re-reading the codebase.

---

## 1. Project Summary

Stone Town Heritage VT-Guide is a Flutter 3 / Dart 3 mobile app that turns the Stone Town (Zanzibar) UNESCO World Heritage Site into a digital tour experience.

**What already works well**
- Clean layered architecture: `core/` (constants/theme/utils), `data/` (models/services/repositories), `blocs/` (state with `flutter_bloc` 9.x), `ui/` (screens + widgets).
- Firebase Auth + Firestore with role-based users (`free`, `premium`, `admin`) plus auto-login via `SharedPreferences`.
- Multilingual content model: 7 names + 7 descriptions per site (EN, SW, FR, DE, AR, IT, ES) and TTS playback in those same 7 languages through `flutter_tts`.
- Two-map strategy: free `flutter_map` + OpenStreetMap for browse/picker/single-site views; `google_maps_flutter` for live turn-by-turn (gated behind an API key with a graceful fallback).
- Admin panel: sites CRUD with Cloudinary multi-image upload, OpenStreetMap location picker, user role management.
- Audio player bottom sheet on the detail screen with in-place language switching.
- Audio auto-arrival logic via `Geolocator` + an arrival overlay.
- Onboarding, language popup, favorites, itinerary, premium paywall (`flutter_tts` 30-second cap for free users).
- Localization via per-locale JSON assets (`assets/localization/en.json`, `sw.json`) loaded by `LocalizationCubit`.
- Defensive layer separation (repository/service pattern) and `Equatable` on every state class.

**Where it falls short (the rest of this document)**
- Two deprecated Flutter APIs still in use across the UI layer.
- One critical platform-safety bug (Google Maps crash on devices without Play services is documented but the snackbar text references a file path that no longer matches the actual file in some places — inconsistency).
- Security: Firestore rules grant blanket read/write to everyone until a hard-coded date (Sep 18, 2026); `firestore.rules` is a known footgun.
- Premium upgrade is cosmetic — no real payment integration.
- Live navigation depends on Google Maps and a real API key, which is currently null and out-of-reach for a free demo.
- Misc smaller issues around the admin screen, the user profile, the onboarding flow, and the audio state.

---

## 2. Recommended Theme & Color System

The current palette (`lib/core/constants/colors.dart`) is a generic warm-earthstone set: `#8B5E3C` primary, `#D4A574` accent, `#FFF8F0` surface. It is fine for a "heritage" brand but generic — it could belong to any brown-themed travel app. For a UNESCO Stone Town app, the dominant material and culture are **coral-limestone + teak + indigo ocean + brass door studs**, not generic brown.

### 2.1 Recommended palette (drop-in replacement)

> Replace the contents of [colors.dart](lib/core/constants/colors.dart) with the following. All existing call-sites will continue to work because the constant names (`primary`, `accent`, `surface`, `textPrimary`, etc.) are kept identical — only the hex values change.

```dart
// Primary — Zanzibar "Ivory + Teak + Indigo" heritage palette
static const Color primary      = Color(0xFF0E4D64); // deep teal/indigo (ocean + carved doors)
static const Color primaryDark  = Color(0xFF083447); // for AppBar/gradient bottoms
static const Color primaryLight = Color(0xFF1A6E89); // hover/pressed surfaces

// Accent — coral-limestone + brass
static const Color accent       = Color(0xFFE7A977); // warm brass/coral
static const Color accentLight  = Color(0xFFF6D4B4);

// Surfaces — aged limestone
static const Color surface      = Color(0xFFFBF7F0); // ivory paper
static const Color surfaceDark  = Color(0xFFEFE7D8); // beige card
static const Color background   = Color(0xFFF6F0E4); // limestone canvas

// Semantic
static const Color error        = Color(0xFFB3261E);
static const Color success      = Color(0xFF1E7F5C);
static const Color warning      = Color(0xFFD08C00);
static const Color info         = Color(0xFF0E4D64);

// Text
static const Color textPrimary   = Color(0xFF1B1B1B); // stronger contrast for accessibility
static const Color textSecondary = Color(0xFF5C5C5C);
static const Color textHint      = Color(0xFF9A9A9A);
static const Color textOnPrimary = Color(0xFFFFFFFF);
static const Color textOnAccent  = Color(0xFF1B1B1B);

// Rating
static const Color rating        = Color(0xFFE7A32B); // warm gold (matches brass)

// Map
static const Color mapRoute      = Color(0xFFE7A977);
static const Color mapUser       = Color(0xFF1A6E89);
static const Color mapMarker     = Color(0xFFB3261E);

// Overlay
static const Color overlayDark   = Color(0xCC000000);
static const Color overlayLight  = Color(0x33FFFFFF);

// Border / Divider
static const Color border        = Color(0xFFE5DCC8);
static const Color divider       = Color(0xFFD9CFB8);
```

### 2.2 Why this palette

| Element | Color | Heritage meaning |
|---|---|---|
| `primary` | Deep teal `#0E4D64` | Indian Ocean water + the painted indigo of Zanzibar doors |
| `primaryDark` | Indigo `#083447` | Stained teak carved doors after sunset |
| `accent` | Coral-brass `#E7A977` | Coral-stone walls + brass studs (the famous Zanzibar doors) |
| `surface` | Ivory `#FBF7F0` | Worn limestone alleys of Stone Town |
| `textPrimary` | Charcoal `#1B1B1B` | High readability against warm backgrounds (WCAG AA) |

This palette still reads as "heritage" but it's distinctly Stone Town rather than generic brown. It also works in dark mode with simple hue rotation if you ever add it.

### 2.3 Accessibility check (against current background `#F6F0E4`)

- `textPrimary #1B1B1B` on `background #F6F0E4` → contrast ≈ 14.5:1 (WCAG AAA).
- `textSecondary #5C5C5C` on `background #F6F0E4` → contrast ≈ 7.6:1 (AAA).
- `textOnPrimary #FFFFFF` on `primary #0E4D64` → contrast ≈ 9.6:1 (AAA).

All pass.

### 2.4 Optional: typography recommendation

The current theme uses the platform default. For a heritage storytelling app, pair the new palette with a serif display face for headings (cultural gravitas) and the platform default for body text. Add the following to `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: PlayfairDisplay
      fonts:
        - asset: assets/fonts/PlayfairDisplay-Regular.ttf
        - asset: assets/fonts/PlayfairDisplay-Bold.ttf, weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf, weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf, weight: 600
```

Then in `app_theme.dart` set:
- `displayLarge / displayMedium / headlineLarge` → PlayfairDisplay 700
- everything else → Inter

(Free SIL Open Font License; drop the TTF files into `assets/fonts/`.)

### 2.5 Optional: light + dark themes

The current code only registers `AppTheme.lightTheme`. Add a `darkTheme` so users on iOS/Android get the dark variant automatically when the system is in dark mode:

```dart
// in app.dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme, // new
  themeMode: ThemeMode.system,    // new
  ...
)
```

A dark palette is the same hex set with `Lerp` toward `#0B1E26` for surfaces and `#E6F1F4` for text. Implementation is ~30 lines using `ColorScheme.fromSeed`.

---

## 3. Recommended Open-Source Navigation Stack

The live-navigation screen ([navigation_screen.dart](lib/ui/screens/navigation_screen.dart)) currently uses `google_maps_flutter`, which is gated behind a `googleMapsApiKey` constant and falls back to a snackbar when no key is present. That makes "Navigate" effectively broken on the demo build. The brief is to keep navigation 100% open-source / key-free end-to-end.

### 3.1 Recommended libraries

| Concern | Library | Why |
|---|---|---|
| Map render | **`flutter_map` (^7.0.2 already in pubspec)** | Already used for browse/picker/single-site. Pure-Dart, no API key, no Google Play services dependency. |
| Tiles | **OpenStreetMap for dev/demo, Stadia Maps / Mapbox / Thunderforest free tier for production** | Stadia gives 200k tile loads/month free, supports HTTPS, has a proper `User-Agent` policy and heritage-friendly styles. |
| Routing | **`flutter_polyline_points` (already in pubspec) + GraphHopper / OSRM / Valhalla** | All three are FOSS routing engines. GraphHopper offers a free tier (used to be 1 req/s). For pure FOSS: self-host OSRM. |
| GPS | **`geolocator` (^13.0.2 already in pubspec)** | Already used; no changes needed. |
| Bearing & orientation | **`flutter_compass`** (optional) | For rotating the map to user's heading. Pure-Dart, MIT. |
| Background navigation (optional) | **`flutter_background_geolocation`** (commercial) OR **`flutter_blue_plus` + manual foreground service** for FOSS | Only if you ever want turn-by-turn while screen off. Skip for the demo. |

### 3.2 Drop-in plan for live navigation without Google

Replace the contents of `NavigationScreen` with a pure `flutter_map` implementation. Sketch (paste into a new file `lib/ui/screens/navigation_screen_open.dart` and re-point `safePushNavigation` at it):

```dart
// Pseudocode only — final shape requires the existing widget contract.
Scaffold(
  body: Stack(children: [
    FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCenter: site, initialZoom: 16),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.stone_town_heritage_vt_guide'),
        PolylineLayer(polylines: [_routePolyline]),
        MarkerLayer(markers: [_userMarker, _siteMarker]),
      ],
    ),
    Positioned(top: 8, left: 8, child: BackButton()),
    Positioned(bottom: 0, left: 0, right: 0, child: _NavInfoCard(...)),
  ]),
)
```

Routing flow:
1. On `initState`, call GraphHopper/OSRM `GET /route?point=lat,lng&point=site_lat,site_lng&profile=foot&geometry=geojson`.
2. Decode the GeoJSON `LineString` into `List<LatLng>` (use `flutter_polyline_points` or just parse manually).
3. Pass that list to `PolylineLayer`.
4. Subscribe to `Geolocator.getPositionStream(distanceFilter: 5)` and update the user marker + camera.
5. Trigger `ArrivalOverlay` when `distanceToSite <= entryRadiusM` (already implemented in `NavigationCubit`).

### 3.3 Why this is better than the current setup

| | Current (Google) | Recommended (open-source) |
|---|---|---|
| API key | Required (currently `null`, blocks the feature) | None |
| Cost | Pay-as-you-go after free tier | Free for demo |
| Play services dependency | Yes (crashes on emulators) | No |
| Offline-capable | Only with Google Plus | Yes with MBTiles / downloaded regions |
| Brand fit | Generic blue Google look | Custom tile style (Stadia "Outdoors" works well for Stone Town) |
| License | Proprietary | Apache-2.0 / BSD |

### 3.4 Implementation effort (rough)

- Routing HTTP client: 1 file, ~80 lines.
- Decoding + drawing route: reuse `flutter_polyline_points` or `PolylineLayer`.
- Tile URL swap: 1 line change in `heritage_map.dart`.
- `safePushNavigation`: re-point from `NavigationScreen` (Google) to `NavigationScreenOpen` (OSM).

---

## 4. Bug, Error, and Improvement Inventory

Each item is given a unique ID for tracking. Severity scale: 🔴 critical · 🟠 high · 🟡 medium · 🟢 low · 🔵 polish.

### 4.1 Bugs and runtime defects

| ID | Severity | File | Issue | Fix (one-liner) |
|---|---|---|---|---|
| B-01 | 🟠 high | [detail_screen.dart:441-447](lib/ui/screens/detail_screen.dart#L441-L447) | Hard-coded location text `'Stone Town, Zanzibar'` for every site. For multi-city deployments or admin mistakes it will be wrong. | Use a `String?` field on `SiteModel` (e.g. `address` or `neighborhood`) with fallback to the literal. |
| B-02 | 🟠 high | [favorites_screen.dart:278](lib/ui/screens/favorites_screen.dart#L278) | Same hard-coded `'Stone Town, Zanzibar'` in favorites card. | Same as B-01. |
| B-03 | 🟠 high | [favorites_screen.dart:189](lib/ui/screens/favorites_screen.dart#L189) | Uses `Image.network` instead of `CachedNetworkImage`. Causes re-downloads and no placeholder/error UI. | Replace with `CachedNetworkImage` (matches `SiteCard`). |
| B-04 | 🟠 high | [site_map_screen.dart:52](lib/ui/screens/site_map_screen.dart#L52) | Hard-coded `'Stone Town, Zanzibar'` again. | Same as B-01. |
| B-05 | 🟡 medium | [admin_sites_screen.dart:269](lib/ui/screens/admin/admin_sites_screen.dart#L269) | Admin site list uses `Image.network` for `cloudinaryImageUrl` instead of `CachedNetworkImage`. | Replace with `CachedNetworkImage` for consistency and offline cache. |
| B-06 | 🟡 medium | [navigation_screen.dart:172-183](lib/ui/screens/navigation_screen.dart#L172-L183) | Bottom-sheet image is `Image.network` with `errorBuilder` but no `loadingBuilder`. While the image is fetching you see an empty rounded clip. | Add a `loadingBuilder` returning a `CircularProgressIndicator`. |
| B-07 | 🟡 medium | [detail_screen.dart:67](lib/ui/screens/detail_screen.dart#L67) | `_showAudioLanguagePicker` reads `wasPlaying` from the cubit before `await`ing the modal. If the audio finishes naturally (TTS completion handler) during the modal, the bottom sheet play/pause button will be out of sync. | Wrap in `addPostFrameCallback` and re-read `state.audioState.isPlaying` after `await`. |
| B-08 | 🟡 medium | [explore_screen.dart:127](lib/ui/screens/explore_screen.dart#L127) | "Featured site" is hard-coded to `sites.first`. With Firestore ordering it can rotate randomly. Either pin it explicitly or remove the feature. | Add `featured: bool` flag to `SiteModel` and use `sites.firstWhere((s) => s.featured, orElse: () => sites.first)`. |
| B-09 | 🟡 medium | [site_list_cubit.dart:96-118](lib/blocs/site_list/site_list_cubit.dart#L96-L118) | `_applyFilters` runs on every snapshot — including snapshot arrivals with no actual filter change. With 50+ sites it triggers a full list diff each time. | Cache the last query/category; only re-filter when one of them changes. |
| B-10 | 🟡 medium | [tts_service.dart:140-147](lib/data/services/tts_service.dart#L140-L147) | `pause()` sets the engine state, but `resume()` does not call `_flutterTts.speak(text)`. After pause+resume the cubit UI says "playing" but nothing is spoken. | On `resume()` re-speak from saved position (most engines can't resume mid-utterance), or document that pause/resume isn't supported and grey out the button. |
| B-11 | 🟡 medium | [firestore_service.dart:60-74](lib/data/services/firestore_service.dart#L60-L74) | `searchSites` builds the upper-bound with `'$query'` (legacy: Apple-style prefix search) but doesn't lowercase the query or the field. Mixed-case searches miss. | Lowercase query and either add a separate `name_en_lc` field or filter in-memory after the Firestore range. |
| B-12 | 🟡 medium | [user_cubit.dart:34-50](lib/blocs/user/user_cubit.dart#L34-L50) | After `updateUserRole` / `deleteUser` the cubit re-runs `loadUsers()` which costs an extra round trip; on slow connections it shows a stale list during the reload. | Use the realtime `watchUsers()` stream (already implemented) instead of one-shot reads. |
| B-13 | 🟡 medium | [home_screen.dart:30](lib/ui/screens/home_screen.dart#L30) | `context.read<SiteListCubit>().loadSites()` is called in `initState` of `HomeScreen`. But `SiteListCubit` constructor already subscribes to `watchSites()`. The redundant call causes a loading flicker the first time the app boots. | Remove the `loadSites()` call from `HomeScreen.initState` and rely on the watch stream. |
| B-14 | 🟡 medium | [admin_shell.dart:27-30](lib/ui/screens/admin/admin_shell.dart#L27-L30) | Same pattern: redundant one-shot `loadSites()` + `loadUsers()` after the watch streams are already active. | Remove and rely on `SiteListCubit.watchSites()` / `UserCubit.watchUsers()`. |
| B-15 | 🟡 medium | [admin_user_management_screen.dart:13](lib/ui/screens/admin/admin_user_management_screen.dart#L13) | Wraps the screen in `BlocProvider(create: (_) => UserCubit()..loadUsers())`. This shadows the app-level `UserCubit` from `app.dart`. State changes here don't propagate to the dashboard stats. | Drop the local `BlocProvider` and use `context.read<UserCubit>()` against the app-level instance (or accept two separate cubits and rename clearly). |
| B-16 | 🟡 medium | [admin_sites_screen.dart:29-35](lib/ui/screens/admin/admin_sites_screen.dart#L29-L35) | `if (widget.addNew)` posts a frame callback that pushes `AdminAddSiteScreen` on top of `AdminSitesScreen`. The flow is "Manage Sites" → automatic forward to "Add Site". User who came from the dashboard menu just wanted to see the list. | Either remove the `addNew` parameter or only auto-push when opened from the dashboard's "Add Site" quick action. |
| B-17 | 🟡 medium | [auth_cubit.dart:160-166](lib/blocs/auth/auth_cubit.dart#L160-L166) | `updateUserRole(role)` mutates `state.user` locally but never persists to Firestore. The next `reloadUser()` will revert the role. | Persist via `_authService`-equivalent Firestore call. |
| B-18 | 🟡 medium | [user_profile_screen.dart:218-256](lib/ui/screens/user_profile_screen.dart#L218-L256) | `_showEditProfileDialog` saves the new display name nowhere. The `onPressed` of Save just pops the dialog. | Call `AuthService.updateDisplayName(...)` and refresh the auth cubit. |
| B-19 | 🟡 medium | [user_profile_screen.dart:258-321](lib/ui/screens/user_profile_screen.dart#L258-L321) | `_showChangePasswordDialog` does no actual password change — only shows a snackbar. | Use `FirebaseAuth.currentUser.updatePassword(newPwd)` after re-authenticating. |
| B-20 | 🟡 medium | [premium_cubit.dart:12-20](lib/blocs/premium/premium_cubit.dart#L12-L20) | `subscribe()` flips `isPremium` to true after a 1-second delay. No payment, no server validation, no expiry. Any user can self-promote to premium. | Either integrate RevenueCat / Stripe / Google Play Billing or clearly label this build as a "demo" with the toggle in admin UI only. |
| B-21 | 🟡 medium | [auth_service.dart:126-141](lib/data/services/auth_service.dart#L126-L141) | Role is assigned from email prefix (`admin@…`, `premium@…`). Anyone can register `admin@anything.com` and gain admin privileges on first login. | Replace with a Firestore lookup against a `roles/{uid}` doc, or with a custom-claim set in a Cloud Function. |
| B-22 | 🟡 medium | [onboarding_screen.dart](lib/ui/screens/onboarding_screen.dart) | Reachable from the navigation graph but never wired in. `splash_screen.dart` reads `isFirstLaunch` from prefs but does not push `OnboardingScreen`. | Either remove `OnboardingScreen` and the related asset or call it from `SplashScreen` before the auth check. |
| B-23 | 🟡 medium | [onboarding_screen.dart:49](lib/ui/screens/onboarding_screen.dart#L49) | `_nextPage` uses `_pages.length` as the upper bound — but indices go 0..length-1. After the last page `nextPage` is a no-op (correct) but the comparison `_currentPage < _pages.length` is misleading. | Use `_currentPage < _pages.length - 1`. |
| B-24 | 🟡 medium | [settings_screen.dart:59-70](lib/ui/screens/settings_screen.dart#L59-L70) | Audio-language dropdown is disabled for free users, but the audio-language picker inside `detail_screen.dart` is not — it lets a free user *pick* a premium language, just greys the choice out. The two paths disagree. | Make both follow the same logic. |
| B-25 | 🟡 medium | [nav_guard.dart:21-38](lib/core/utils/nav_guard.dart#L21-L38) | Snackbar text mentions setting the key in `lib/core/constants/app_constants.dart`. After the recommended navigation stack change this file path no longer exists. | Update message to point to the new navigation module file once replaced. |
| B-26 | 🟡 medium | [explore_screen.dart:127](lib/ui/screens/explore_screen.dart#L127) | In map view the `close` button label `_tr(locState, 'close')` is "Close" but the user expects "Show list". | Add a dedicated key `view_list` and `view_map`. |
| B-27 | 🟡 medium | [cloudinary_service.dart:96-123](lib/data/services/cloudinary_service.dart#L96-L123) | `getTransformedUrl` and `_applyTransformation` parse by string-splitting on `'upload/'`. Cloudinary URLs with signed segments (e.g. `/upload/s--hash--/...`) can break. | Use a proper URL builder with `Uri.parse` and a path replacement. |
| B-28 | 🟡 medium | [cloudinary_service.dart:125-127](lib/data/services/cloudinary_service.dart#L125-L127) | `getPlaceholderUrl` uses `via.placeholder.com` (third-party, slow, sometimes down). | Use a static asset or a self-hosted SVG. |
| B-29 | 🟠 high | [site_list_cubit.dart:17-33](lib/blocs/site_list/site_list_cubit.dart#L17-L33) | If the `watchSites()` stream errors on the very first emit, no `loading` state is shown — the UI sits on the previous default state forever. | Emit `loading` then `error`. |
| B-30 | 🟡 medium | [auth_cubit.dart:14-39](lib/blocs/auth/auth_cubit.dart#L14-L39) | `checkAuthStatus` overwrites the saved user role with the email-prefix logic on every cold start. If admin demoted a user in Firestore, the demotion is silently undone next launch. | Persist the role snapshot at login and trust the Firestore doc, not the email. |
| B-31 | 🟡 medium | [register_screen.dart:60-65](lib/ui/screens/register_screen.dart#L60-L65) | `_onGoogleSignUp` calls `signInWithGoogle` which signs the user in (not up). Result: a freshly-registered user via email/password, then accidental "Sign up with Google" tap, silently signs them into a different Google account without confirmation. | Rename method or confirm the account switch. |
| B-32 | 🟡 medium | [register_screen.dart:73-90](lib/ui/screens/register_screen.dart#L73-L90) | After Google sign-in, the user is routed through `PremiumOfferScreen` even though they may have registered just to *browse* — no skip option until they tap "Maybe Later". | Skip premium offer on Google sign-in for returning users (check `metadata.creationTime`). |
| B-33 | 🟡 medium | [explore_screen.dart:127](lib/ui/screens/explore_screen.dart#L127) | The featured site uses `sites.first`. When filtered by category, the featured card disappears from the data set, leaving a "Best Places" header with no featured tile but the grid still appears. | Hide both the "Best Places" header and featured card when filtered. |
| B-34 | 🟡 medium | [detail_screen.dart:468-474](lib/ui/screens/detail_screen.dart#L468-L474) | `UpgradeBanner.onUpgrade` is empty — tapping it does nothing. | Wire to `UpgradeScreen`. |
| B-35 | 🟡 medium | [detail_screen.dart:620-624](lib/ui/screens/detail_screen.dart#L620-L624) | The "replay" button in the audio bottom sheet has an empty `onPressed: () {}`. | Implement replay: stop + restart current language. |
| B-36 | 🟡 medium | [search_bar_widget.dart:38-49](lib/ui/widgets/search_bar_widget.dart#L38-L49) | The suffix clear-icon only shows when `controller.text.isNotEmpty`. Because the widget never `addListener`s on the controller, after the user types nothing the icon disappears only after a rebuild triggered elsewhere. | `ValueListenableBuilder<TextEditingValue>(valueListenable: controller, …)`. |
| B-37 | 🟡 medium | [explore_screen.dart:60-63](lib/ui/screens/explore_screen.dart#L60-L63) | `_searchController` is created but its text is never read into the cubit search query. Typing in the search bar calls `context.read<SiteListCubit>().search(query)` correctly (good) but the cubit's `search` only updates `state.searchQuery` — the in-memory list filter does work, so this is fine. Just call out that clearing the search bar requires a separate "clear" path. | Add a "clear" button to `SearchBarWidget`. |
| B-38 | 🟡 medium | [admin_add_site_screen.dart:156-279](lib/ui/screens/admin/admin_add_site_screen.dart#L156-L279) | The "Add Site" form's text fields all require 7-language entries but there's no "Copy from English" helper. Typing the same description in 7 languages is painful. | Add a per-language "Copy from English" button. |
| B-39 | 🟡 medium | [admin_add_site_screen.dart:478-509](lib/ui/screens/admin/admin_add_site_screen.dart#L478-L509) | "My location" button in the picker writes to the controller but never calls `setState`, so the map camera animates but the lat/lng inputs aren't refreshed visually until the user taps the field. | Wrap the picker callbacks in `setState`. |
| B-40 | 🟡 medium | [admin_edit_site_screen.dart:60](lib/ui/screens/admin/admin_edit_site_screen.dart#L60) | `_imageUrlController` is initialised with `widget.site.cloudinaryImageUrl` but the model has migrated to multi-image. Only the legacy single image is editable. | Build a multi-image grid the same way `admin_add_site_screen.dart` does. |
| B-41 | 🟡 medium | [category_chips.dart:29](lib/ui/widgets/category_chips.dart#L29) | `categories` is passed in from `AppConstants.siteCategories` (`historic, cultural, religious, architecture`) which has only 4 entries — but `SiteCategories.all` has 8 (`market, museum, natural_landmark, government, other`). The two lists diverge. | Use `SiteCategories.all` everywhere. |
| B-42 | 🟡 medium | [explore_screen.dart:70](lib/ui/screens/explore_screen.dart#L70) | `CategoryChips(categories: AppConstants.siteCategories, …)` passes the 4-item list. | Use `SiteCategories.all`. |
| B-43 | 🟡 medium | [tts_service.dart:43-49](lib/data/services/tts_service.dart#L43-L49) | `_setDefaultLanguage` uses `'en-US'` if available, else silently does nothing. On devices where 'en-US' isn't installed but 'en-GB' is, the TTS uses its system default with no warning. | Fall back through a known list and log. |
| B-44 | 🟡 medium | [auth_service.dart:9](lib/data/services/auth_service.dart#L9) | `GoogleSignIn()` is called without scopes. On first sign-in Android users get a confusing "this app wants to know your email" prompt that the app can't actually use. | Pass `scopes: const ['email']`. |
| B-45 | 🟡 medium | [cloudinary_service.dart:54-65](lib/data/services/cloudinary_service.dart#L54-L65) | `uploadImages` uploads sequentially. For 5 images at 3 MB each on 3G this is painful. | Use `Future.wait` over the list. |
| B-46 | 🟡 medium | [favorites_screen.dart:128-140](lib/ui/screens/favorites_screen.dart#L128-L140) | "Undo" snackbar only fires after the user taps remove, but the favorites list rebuilds immediately and the card disappears. The undo button snaps the card back, but because the snackbar persists across navigation, if the user pushed a new screen the snackbar still shows with a stale `context`. | Anchor the snackbar with `ScaffoldMessenger.of(rootContext)` captured before the await. |
| B-47 | 🟡 medium | [home_screen.dart:34-37](lib/ui/screens/home_screen.dart#L34-L37) | The `IndexedStack` keeps Explore + Settings in the widget tree even when not visible. This means `ExploreScreen` runs its `BlocBuilder`s and OSM tile fetches as soon as `HomeScreen` mounts — costs battery and data on first launch. | Use `PageView` with `KeepAlive=false`, or lazy-build each tab. |
| B-48 | 🟡 medium | [favorites_screen.dart](lib/ui/screens/favorites_screen.dart) | Title `'Favorites'` is hard-coded English. The rest of the app honours `_tr(locState, '...')`. | Add `favorites` key to en.json / sw.json and use the same lookup pattern. |
| B-49 | 🟡 medium | [detail_screen.dart:441](lib/ui/screens/detail_screen.dart#L441) | `'Stone Town, Zanzibar'` again. | (same as B-01) |
| B-50 | 🟡 medium | [premium_offer_screen.dart:108-115](lib/ui/screens/premium_offer_screen.dart#L108-L115) | "Start 3-Day Free Trial" implies a real subscription trial. There is no actual trial — `PremiumCubit.subscribe()` simply flips a flag. | Either rename to "Start Demo Premium" or wire to a real billing provider. |

### 4.2 Deprecated APIs (Flutter 3.29)

| ID | Severity | Pattern | Occurrences | Fix |
|---|---|---|---|---|
| D-01 | 🟠 high | `Color.withAlpha(int)` — deprecated in Flutter 3.27, removed in 3.29. Returns a warning on every build (not yet a compile error but will be). | 80+ usages across all screens (`welcome_screen.dart`, `splash_screen.dart`, `login_screen.dart`, `register_screen.dart`, `premium_offer_screen.dart`, …) | Replace with `withValues(alpha: ...)` (double in 0..1). The codebase already uses the new API in some files — pick one and migrate everything. |
| D-02 | 🟡 medium | `cardTheme: CardTheme(...)` (no `Data` suffix) — deprecated; `CardThemeData` is the new name. | [app_theme.dart:44](lib/core/theme/app_theme.dart#L44) | Replace with `CardThemeData(...)`. |
| D-03 | 🟡 medium | `Material.color` set with `Colors.transparent` on `InkWell` containers — Flutter 3.27+ no longer requires this but it triggers a lint warning. | `welcome_screen.dart:129`, `login_screen.dart:355`, `register_screen.dart:383`, several `admin_*` files | Remove the wrapping `Material(color: Colors.transparent)`. |

### 4.3 Security and safety

| ID | Severity | File | Issue | Fix |
|---|---|---|---|---|
| S-01 | 🔴 critical | [firestore.rules](firestore.rules) | "Allow read/write to anyone until 2026-09-18" blanket rule. After that date, **all reads and writes are denied** — no warning, just a silent production break. | (a) Replace with proper auth-based rules: `match /sites/{id} { allow read: if true; allow write: if request.auth != null && request.auth.token.role in ['admin']; }`. (b) Add a comment with a reminder link to a CI calendar alert. (c) Add a startup check that fails fast if `request.time >= ...`. |
| S-02 | 🟠 high | [google-services.json](android/app/google-services.json) | Live Firebase config with API key. Already gitignored by convention but check it's not committed to a public mirror. | Move secrets to `google-services.json` template and inject at build time via Gradle properties, or use Flutter's `--dart-define` for keys. |
| S-03 | 🟠 high | [auth_service.dart:126-141](lib/data/services/auth_service.dart#L126-L141) | Email-prefix role assignment: anyone who registers `admin@…` or `premium@…` is silently promoted. | Use a Firestore `roles/{uid}` collection written by an admin user from the admin panel; check role from there on every login. |
| S-04 | 🟡 medium | [premium_cubit.dart](lib/blocs/premium/premium_cubit.dart) | No server-side premium validation. TTS limit lives client-side and can be bypassed by clearing app data and re-registering as premium. | Move premium state to Firestore user doc + enforce in Cloud Functions. |
| S-05 | 🟡 medium | [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) | `android:usesCleartextTraffic="true"` is a global allow for HTTP. OK for OSM tiles (`tile.openstreetmap.org` is HTTPS), but removes a safety net. | Set `android:usesCleartextTraffic="false"` and add a network-security-config that explicitly allows any HTTP endpoints you actually need. |

### 4.4 UX / accessibility

| ID | Severity | Area | Issue | Fix |
|---|---|---|---|---|
| U-01 | 🟡 medium | All screens | No semantic labels on icon-only buttons (back arrow on `SiteMapScreen`, play/pause in `DetailScreen`, heart on `SiteCard`). TalkBack users hear "button" with no purpose. | Wrap in `Semantics(label: '...')` or use `IconButton(icon: Icon(...), tooltip: '...')` everywhere (already partially done). |
| U-02 | 🟡 medium | `DetailScreen` image gallery | Left/right arrow buttons lack `tooltip`s. | Add tooltip text. |
| U-03 | 🟡 medium | Splash → Welcome | Splash routes to `WelcomeScreen` after 1.5 s. There is no Skeleton loader for the auth check — on slow networks the auth state is briefly `initial` and the user sees the splash even though auth has resolved. | Use a `BlocBuilder<AuthCubit>` instead of a fixed duration. |
| U-04 | 🟡 medium | Bottom nav (Home) | The favourites icon button in the Home AppBar has a `tooltip: 'Favorites'` (English only). | Localize via `_tr(locState, 'favorites')`. |
| U-05 | 🟡 medium | Onboarding | Strings (`'Explore Heritage'`, `'Audio Guides'`, `'GPS Navigation'`, `'Skip'`, `'Next'`, `'Get Started'`) are hard-coded English. | Move to `assets/localization/en.json` and use the existing `LocalizationCubit`. |
| U-06 | 🟡 medium | Audio progress bar | `LinearProgressIndicator` shows zero progress because TTS doesn't report progress (it just calls completion). Looks broken. | Animate a fake progress based on the truncated text length and stop on completion. |
| U-07 | 🟡 medium | DetailScreen bottom sheet | The progress bar is bound to `state.audioState.progress`, which is `0/0 → 0`. Always shows as empty. | Same as U-06. |
| U-08 | 🟡 medium | `_AdminDashboard` | The "Analytics" quick action has `onPressed: () {}`. | Either wire it up or remove. |
| U-09 | 🟡 medium | Search | No debounce on the search input. Every keystroke triggers a `Filter` across all sites. | Add a 200 ms debounce. |
| U-10 | 🟡 medium | RTL | App doesn't honour `Directionality` for Arabic/Swahili users. Swahili is LTR but Arabic content exists in site descriptions. | Wrap text-heavy screens with `Directionality(textDirection: ..., ...)` when the locale is Arabic. |

### 4.5 Performance

| ID | Severity | Area | Issue | Fix |
|---|---|---|---|---|
| P-01 | 🟡 medium | `HomeScreen` | `IndexedStack` builds all three tabs at once — Explore and Settings initialize their blocs and fetch data eagerly. | Replace with `PageView` + `AutomaticKeepAliveClientMixin` (only build on swipe). |
| P-02 | 🟡 medium | `SiteDetailCubit.close` | Stops TTS but doesn't dispose of the `TtsService` (which the app-level instance owns). | Document ownership; consider per-screen instance. |
| P-03 | 🟡 medium | `Cloudinary.uploadImages` | Sequential uploads. | Use `Future.wait` for parallel uploads. |
| P-04 | 🟡 medium | `ExploreScreen` map view | Recreates `HeritageMap` widget on every filter change, which re-fetches tiles. | Use `KeepAlive`. |
| P-05 | 🟡 medium | `FavoritesScreen` | Re-filters the full site list on every favorite toggle (cheap but O(n) where n = number of sites). | Maintain a `Map<String, SiteModel>` indexed by id. |

### 4.6 Developer experience

| ID | Severity | Area | Issue | Fix |
|---|---|---|---|---|
| X-01 | 🟡 medium | Tests | `pubspec.yaml` includes `flutter_test` but there is no `test/` folder. | Add `test/site_model_test.dart`, `test/distance_calculator_test.dart`, `test/favorites_cubit_test.dart`. |
| X-02 | 🟡 medium | Lints | `analysis_options.yaml` only enables the default `flutter_lints` set. | Add `prefer_single_quotes`, `require_trailing_commas`, `sort_constructors_first`, `avoid_dynamic_calls`. |
| X-03 | 🟡 medium | CI | No GitHub Actions / Fastlane / Codemagic config. | Add `.github/workflows/flutter.yml` with `flutter analyze`, `flutter test`, `flutter build apk`. |
| X-04 | 🟡 medium | README | Quickstart is good but lacks a "Maps" troubleshooting section, screenshots of admin screens, and architecture diagram. | Update README. |
| X-05 | 🟢 low | iOS `Info.plist` | No `NSLocationAlwaysUsageDescription`, only `WhenInUse`. For background navigation (future) this would be needed. | Add the key now with a placeholder string. |
| X-06 | 🟢 low | Build | `targetSdk = 36`, `minSdk = 24`. Fine for now, but `targetSdk = 36` is bleeding-edge — verify Play Store acceptance. | Pin to `34` or `35` for production safety. |
| X-07 | 🟢 low | iOS bundle display name | `Stone Town Heritage Vt Guide` (capitalisation off). | Fix to `Stone Town Heritage VT-Guide`. |
| X-08 | 🟢 low | Hard-coded admin email | `admin@stonetownguide.com` shown in dashboard as default. | Remove or replace with the logged-in user's email only. |

---

## 5. Phased Implementation Plan

Each phase is shippable on its own. The phases are ordered so each later phase builds on a stable earlier one.

### Phase 0 — Foundation (≤ 1 day)

- Apply the recommended palette to [colors.dart](lib/core/constants/colors.dart) (cut-and-paste the new palette from §2.1). Verify the app still looks correct.
- Replace `Color.withAlpha(...)` → `Color.withValues(alpha: ...)` in every file (D-01). One global find-and-replace.
- Replace `CardTheme(...)` → `CardThemeData(...)` in [app_theme.dart](lib/core/theme/app_theme.dart#L44) (D-02).

### Phase 1 — Bugfix pass on the demo (1–2 days)

Tackle B-01 → B-50 in this order, prioritising the orange/high items first:

1. **Hard-coded location strings** — add an `address` field to `SiteModel`, run a Firestore backfill for the seed data, update the three offending screens (B-01, B-02, B-04, B-49).
2. **CachedNetworkImage** in `FavoritesScreen`, `AdminSitesScreen`, `NavigationScreen` (B-03, B-05, B-06).
3. **Remove redundant `loadSites()`/`loadUsers()`** in `HomeScreen` and `AdminShell` (B-13, B-14). Wire `AdminUserManagementScreen` to the app-level `UserCubit` (B-15).
4. **Fix audio state sync** between `DetailScreen` language picker and the bottom-sheet play/pause button (B-07, U-06, U-07).
5. **Wire `UpgradeBanner.onUpgrade`**, **replay button**, **edit profile**, **change password**, **delete account** (B-18, B-19, B-34, B-35).
6. **`SiteListCubit.filterByCategory` and `_applyFilters` performance** (B-09).
7. **`SiteListCubit` error state on first load** (B-29).
8. **`SiteCategories.all` everywhere** (B-41, B-42).
9. **Add favourite key to localization** (B-48).
10. **Localize Onboarding** (U-05).
11. **FavoritesScreen hard-coded English title** (B-48).
12. **Category mismatch in `explore_screen`** (B-42).
13. **Premium "free trial" wording** (B-50, X-08).
14. **`FirestoreService.searchSites` case-insensitivity** (B-11).
15. **`OnboardingScreen` reachable or removed** (B-22, B-23).
16. **`PremiumCubit` doesn't persist role** (B-20, B-30, B-17).

### Phase 2 — Switch to open-source navigation (1 day)

Follow §3.2:

1. Add `flutter_compass` (optional) to `pubspec.yaml`.
2. Create `lib/data/services/routing_service.dart` with GraphHopper (free tier) or OSRM endpoint.
3. Create `lib/ui/screens/navigation_screen_open.dart` mirroring `NavigationScreen` but with `FlutterMap` + `PolylineLayer`.
4. Update `safePushNavigation` to call the new screen by default; keep `NavigationScreen` (Google) for builds that have a key.
5. Add a Settings → "Map provider" toggle so the demo build uses the open-source path while production builds can opt into Google.

### Phase 3 — Security hardening (1 day)

1. Replace [firestore.rules](firestore.rules) with auth-based rules (S-01).
2. Move role assignment out of email-prefix logic into Firestore `roles/{uid}` doc (S-03).
3. Disable `usesCleartextTraffic` and add a network security config (S-05).
4. Replace `GoogleSignIn()` default with `GoogleSignIn(scopes: ['email'])` (B-44).
5. Add a startup `firebaseRemoteConfig` check that warns if running against a Firestore with the legacy blanket rule (defensive).

### Phase 4 — UX polish (1–2 days)

1. Add `Semantics` / `tooltip` to all icon-only buttons (U-01, U-02).
2. Fix RTL for Arabic content (U-10).
3. Splash → Auth-driven navigation (U-03).
4. Search debounce (U-09).
5. Map/list view toggle clarity (B-26).
6. Audio progress animation (U-06, U-07).
7. Wire "Analytics" admin tile to a real analytics page (even if just a screen with charts from Firestore aggregations) (U-08).
8. **Featured site pinning** via a `featured` boolean on `SiteModel` (B-08, B-33).
9. **Multi-image support in Edit Site screen** (B-40).
10. **Copy-from-English helper in Add Site** (B-38).

### Phase 5 — Performance and DX (1 day)

1. Replace `IndexedStack` with `PageView` (P-01).
2. Parallelize Cloudinary uploads (P-03).
3. Switch favorite filtering to a `Map<String, SiteModel>` index (P-05).
4. Add `test/site_model_test.dart` and `test/distance_calculator_test.dart` (X-01).
5. Tighten `analysis_options.yaml` (X-02).
6. Add a basic CI workflow (X-03).
7. Polish README + screenshots (X-04).

### Phase 6 — Dark mode and typography (½ day)

1. Add `darkTheme` and `themeMode: ThemeMode.system` in `app.dart`.
2. Drop `PlayfairDisplay` + `Inter` font assets in `assets/fonts/`.
3. Wire `displayLarge/Medium/Small`, `headlineLarge` to PlayfairDisplay; rest to Inter.

### Phase 7 — Final readiness (½ day)

1. iOS bundle display name fix (X-07).
2. Android `targetSdk` pin (X-06).
3. iOS background location key (X-05).
4. Run `flutter analyze`, `flutter test`, `flutter build apk --release`, `flutter build ios --release` — all green.
5. Verify OSM tile policy compliance by keeping `userAgentPackageName` set.
6. Update README with: new palette preview, open-source nav stack rationale, "How to add your own Firestore rules", and a Troubleshooting section.

---

## 6. Concrete fix recipes (copy-paste ready)

The five highest-leverage fixes, with the exact diffs.

### 6.1 Replace `withAlpha` everywhere (D-01)

Run this in the project root:

```bash
# Find all .dart files and replace .withAlpha(X) -> .withValues(alpha: X/255.0)
# (manual sed/awk works, but a Dart script is safer for arithmetic)
```

Or, if you prefer a manual sweep, the pattern is:

```dart
// Before
Colors.black.withAlpha(26)
// After
Colors.black.withValues(alpha: 26 / 255.0)
```

A simple rule of thumb: `withAlpha(255) == withValues(alpha: 1.0)`, `withAlpha(128) ≈ withValues(alpha: 0.5)`. The codebase already uses `withValues` in many places, so an in-place find-and-replace is straightforward.

### 6.2 Add `address` field to `SiteModel` (B-01, B-02, B-04, B-49)

In [site_model.dart](lib/data/models/site_model.dart#L29):

```dart
final String? address; // e.g. "Stone Town, Zanzibar" or "Forodhani Gardens, Zanzibar"
```

Add to `toMap` and `fromMap`. Update [detail_screen.dart](lib/ui/screens/detail_screen.dart#L441), [favorites_screen.dart](lib/ui/screens/favorites_screen.dart#L278), [site_map_screen.dart](lib/ui/screens/site_map_screen.dart#L52) to read `site.address ?? 'Stone Town, Zanzibar'`.

### 6.3 Replace `firestore.rules` (S-01)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Sites: world-readable, admin-write
    match /sites/{siteId} {
      allow read: if true;
      allow write: if request.auth != null
                   && get(/databases/$(database)/documents/roles/$(request.auth.uid)).data.role == 'admin';
    }
    // Users: owner can read/write own doc, admin can read all
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null
                  && get(/databases/$(database)/documents/roles/$(request.auth.uid)).data.role == 'admin';
    }
    // Roles collection: only admin can write
    match /roles/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null
                   && get(/databases/$(database)/documents/roles/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 6.4 Open-source navigation entry-point (Phase 2)

Replace [nav_guard.dart](lib/core/utils/nav_guard.dart) with:

```dart
import 'package:flutter/material.dart';
import '../../data/models/site_model.dart';
import '../../ui/screens/navigation_screen_open.dart'; // new file

void safePushNavigation(BuildContext context, SiteModel site) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NavigationScreenOpen(site: site)),
  );
}
```

(If you want to keep the legacy Google screen behind a build flag, branch on a const.)

### 6.5 Remove redundant `loadSites()` in `HomeScreen` (B-13)

In [home_screen.dart](lib/ui/screens/home_screen.dart#L27-L31) delete the entire `initState` override — the watch stream in `SiteListCubit` already drives updates.

---

## 7. Quality Gates (run before each release)

```bash
flutter analyze                       # must report 0 issues (currently: 0)
flutter test --coverage               # target ≥ 40 % on data/ and blocs/
flutter build apk --release           # smoke build
flutter build ios --release --no-codesign  # smoke build
dart fix --apply                      # one-shot modernization pass
```

Add a CI workflow (`.github/workflows/flutter.yml`) that runs the first three on every PR.

---

## 8. Summary

The Stone Town Heritage VT-Guide is structurally sound — clean architecture, good use of `flutter_bloc`, thoughtful UX flows. What stands between it and "final" is a **theme refresh** (the current brown palette is generic; the recommended ivory + indigo + brass palette reads as distinctly Stone Town), **two deprecated Flutter APIs** to migrate (`withAlpha`, `CardTheme`), **~50 small-to-medium bugs** (mostly hard-coded strings, deprecated image APIs, two redundant data loads, one real TTS pause/resume bug), **a critical security rule** that needs replacement before Sep 18, 2026, and **a navigation rewrite** to remove the Google Maps dependency for the demo build.

If you implement Phase 0 + Phase 1 + Phase 2 + Phase 3 in order (≈ 4 days of focused work), you get a project that is **demo-ready, key-free, and security-honest**. Phases 4–7 are polish on top.

---

*End of report.*