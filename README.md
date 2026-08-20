# Stone Town Heritage VT-Guide 🏛️

A digital tour guide app for Stone Town, Zanzibar (UNESCO World Heritage Site). Built with Flutter & Firebase.

## Features

### 👤 User Features
- **Multi-language Support** - English & Swahili (Swahili: Kiswahili)
- **Heritage Site Browsing** - Browse historic, cultural, religious, and other sites
- **GPS Navigation** - Navigate to heritage sites with live directions
- **Audio Guides** - Text-to-Speech descriptions in 7 languages (EN, SW, FR, DE, AR, IT, ES)
- **User Authentication** - Email/password & Google Sign-In
- **User Roles** - Free, Premium, and Admin accounts
- **Premium Upgrade** - Unlock all 7 audio languages

### 🔐 Authentication & Roles
- Email/Password registration and login
- Google Sign-In integration
- Firebase Authentication
- Role-based access (Free, Premium, Admin)
- Auto-login for returning users
- Session persistence with SharedPreferences

### 👨‍💼 Admin Panel
- **Dashboard** - Overview with stats (sites, users, premium count)
- **Site Management**
  - Add new heritage sites
  - Edit existing sites
  - Delete sites
  - Multi-image upload with Cloudinary
  - Interactive OpenStreetMap location picker
  - Auto-translation to 7 languages
- **User Management**
  - View all users
  - Change user roles (Free/Premium/Admin)
  - Enable/Disable accounts
  - Search users
- **Admin Settings**
  - Default language preferences
  - Account info

### 🗺️ Site Management
- **Categories**: Historic, Cultural, Religious, Market, Museum, Natural Landmark, Government, Other
- **Multi-language Content**: Names and descriptions in 7 languages
- **Photo Gallery**: Multiple images per site
- **Location**: GPS coordinates with entry radius (10-200m)
- **Auto-translation**: Admin enters all 7 languages by hand when adding a site. (The original Google Cloud Translation path was removed — paid API not needed for a demo.)

### 🎨 UI/UX
- Modern Material Design 3
- Dark theme with stone/heritage color palette
- Bottom navigation (Home, Explore, Settings)
- Pull-to-refresh
- Loading states and error handling
- Responsive cards and lists
- Gradient backgrounds

## Technical Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| State Management | flutter_bloc (Cubit) |
| Backend | Firebase (Auth, Firestore) |
| Image Storage | Cloudinary |
| Maps (browse, view, picker, live navigation) | `flutter_map` + CARTO Voyager tiles (free, no API key) |
| Maps (live navigation) | `google_maps_flutter` — **gated behind an API key** in `AppConstants.googleMapsApiKey`. Without a key, "Navigate" buttons show a friendly explanation instead of opening the screen, because the Google Maps SDK crashes on emulators and devices without Google Play services / billing. |
| Text-to-Speech | flutter_tts |
| Location | Geolocator |
| Local Storage | SharedPreferences |

## Project Structure

```
lib/
├── blocs/               # State management
│   ├── auth/           # Authentication
│   ├── language/       # Language settings
│   ├── localization/   # Translations
│   ├── navigation/     # GPS navigation
│   ├── premium/        # Premium status
│   ├── site_detail/    # Site details
│   ├── site_list/      # Sites list
│   ├── user/           # User management
│   └── explore/        # Explore/filter
├── core/
│   ├── constants/      # Colors, strings
│   └── theme/          # App theme
├── data/
│   ├── models/         # Data models
│   └── services/       # Firebase, Cloudinary, etc.
├── localization/        # EN & SW translations
└── ui/
    ├── screens/        # All screens
    └── widgets/        # Reusable widgets
```

## Setup Instructions

### 1. Firebase Setup
1. Create a Firebase project
2. Enable Authentication (Email/Password + Google)
3. Create Firestore database
4. Copy `android/app/google-services.json.example` → `android/app/google-services.json` and fill in the real keys from your Firebase console (project number, app id, oauth client ids, API key). On iOS, download `GoogleService-Info.plist` from the Firebase console and place it at `ios/Runner/GoogleService-Info.plist`. **Neither file is committed to source control** — see [Security rules](#security-rules) below.

### 2. Cloudinary Setup

### 2. Cloudinary Setup
1. Create Cloudinary account
2. Create upload preset (unsigned)
3. Update `cloudinary_service.dart` with your credentials
   - The default cloud name is `dpmcnfbpb` and the upload preset is `stone_town_unsigned` (both hardcoded in `CloudinaryService`)

### 3. Run the App
```bash
flutter pub get
flutter run
```

## Security rules

Firestore security rules live in [firestore.rules](firestore.rules). They enforce:

- **`sites`** — world-readable, admin-only writes.
- **`users/{uid}`** — owner can read/write their own profile; admins can read all users (needed for the Admin → User Management screen).
- **`roles/{uid}`** — only writable by an existing admin. Reads allowed for the owner and admins.
- **Everything else** — default-deny.

Deploy after every change:

```bash
firebase deploy --only firestore:rules
```

Or paste the file into the Firebase console editor. The rules are loaded by Firestore at request time, not bundled with the app, so a deploy is required.

## Roles model

User roles live in the Firestore `roles/{uid}` collection with the shape:

```json
{ "role": "free" | "premium" | "admin", "updated_at": <server timestamp> }
```

- New users default to `free`. No `roles/{uid}` doc is created on signup — `UserRole.free` is implicit.
- Promotion / demotion is performed from the Admin → User Management screen, which writes `roles/{uid}` directly.
- A future Cloud Functions phase will move promotion behind a trusted-server boundary and switch the rules' admin check to custom claims.
- For pre-Phase-3 legacy users, the client still falls back to reading `users/{uid}.role` if no `roles/{uid}` doc exists. This fallback is TODO-marked in `AuthService._createUserModel` and `AuthCubit.checkAuthStatus` for removal.

## Maps

The app uses two map libraries, chosen for their respective strengths:

- **`flutter_map` + OpenStreetMap (CARTO Voyager tiles)** is used for **all** map screens, including live navigation:
  - Explore screen's "Map view" (taps a marker to open site detail)
  - "View on Map" screen for a single site (with a Navigate FAB)
  - Admin "Add Site" and "Edit Site" location pickers (drag the pin, tap to drop a new one, "My location" button snaps to GPS)
  - Live navigation screen (`NavigationScreenOpen`) — GPS-follow camera, polyline, arrival detection, off-route detection, rerouting. No Google Maps API key is required.
- **Routing engine**: `RoutingService` talks to the public OSRM foot profile (`https://router.project-osrm.org/route/v1/foot`) with a 30-minute in-memory cache. An optional OpenRouteService key is supported via `runtimeConfig` if the public demo is rate-limited.
- **Tile caching**: `TileCacheService` provides a disk-backed tile cache so previously-visited tiles render offline.

### Tile usage

`flutter_map` fetches tiles from CARTO's free Voyager basemap (`https://{a-d}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png`). CARTO's free tier is fine for development and low-traffic demos and is faster / better-styled than the raw OSM tile server. For production deployment, switch to a paid tile provider (Stadia Maps, Mapbox, etc.) — only [lib/ui/widgets/heritage_map.dart](lib/ui/widgets/heritage_map.dart) would need to change.

## Architecture

The application follows a clean layered architecture using `flutter_bloc`:

- **core/**: Theme definitions, constants, colors, and global utils. Includes the GPS smoothing (`GpsFilter`), heading source (`HeadingSource`), off-route hysteresis (`OffRouteHysteresis`), and orthogonal polyline projection (`PolylineSnap`).
- **data/**: Data Models (`SiteModel`), Services (`AuthService`, `FirestoreService`, `CloudinaryService`, `RoutingService`, `LocationService`, `TileCacheService`), Repositories.
- **state/**: Cross-cutting state managers shared between screens. Currently `MapCameraController` — owns the `MapController` and exposes a `CameraMode` enum so the navigation screen and the heritage map share the same camera state instead of fighting each other.
- **blocs/**: Business logic using Cubits. Separated by feature (e.g., `SiteListCubit`, `AuthCubit`, `ExploreCubit`, `NavigationCubit`).
- **ui/**: Screens and reusable Widgets.

### Navigation state machine

The `NavigationCubit` is the single source of truth for live-navigation state. It owns:

- **Permission gating** — emits `permission_denied` if the user hasn't granted location.
- **Bounds check** — emits `destination_out_of_bounds` for sites outside Unguja.
- **GPS smoothing** — wraps every Position in `GpsFilter` (accuracy-weighted EMA + 3σ outlier rejection).
- **Heading** — uses `HeadingSource` (EMA + GPS-derived bearing fallback when `pos.heading == 0`).
- **Off-route detection** — `OffRouteHysteresis` (cross-track > 30 m sustained for 1.5 s).
- **Arrival debounce** — requires 2 consecutive fixes inside the entry radius (3 for ≥ 50 m radii) before firing `NavigationStatus.arrived`. Once fired, the state stays `arrived` so the banner doesn't flicker off on subsequent fixes.
- **Session reentrancy** — a monotonically increasing `_sessionId` is checked by every async callback so a stale GPS fix from a previous navigation can't update the new state.

## Troubleshooting

### Maps Troubleshooting
- **Routing engine flakiness**: The public OSRM demo can be slow or rate-limited. The `RoutingService` returns a 2-point straight-line fallback if the request fails or times out — the camera and HUD still work, just without turn-by-turn.
- **Tile provider**: For production, replace the CARTO Voyager URL in `HeritageMap` with your paid provider (e.g. Stadia Maps, Mapbox).

## Screenshots

*Admin Dashboard & Site Management*
> [Placeholder: Add screenshots of the admin panel here]

*Explore & Heritage Map*
> [Placeholder: Add screenshots of the Explore screen and Heritage Map here]

*Site Detail & Audio Player*
> [Placeholder: Add screenshots of the Site Detail screen and Bottom Audio Player here]

## Firebase

This project uses Firebase for Auth and Cloud Firestore. The
config files for the Firebase CLI are at the repo root:

- `firebase.json` — tells the CLI what to deploy.
- `firestore.rules` — security rules (`sites`, `activities`, `users`, `roles`).
- `firestore.indexes.json` — composite indexes (empty until needed).
- `.firebaserc` — pins the default project to `stone-town-heritage-vt-guide`.

The Android client reads `android/app/google-services.json` directly.
iOS / web / desktop clients need a generated `lib/firebase_options.dart`
— run `flutterfire configure` if you target those.

### Deploy Firestore rules + indexes

```bash
# One-time per machine
npm install -g firebase-tools
firebase login

# From the repo root
firebase deploy --only firestore
```

That pushes both `firestore.rules` and `firestore.indexes.json`. To
preview a rules change without committing it, run
`firebase emulators:start --only firestore` first.

## License

MIT License - See LICENSE file

---

Built with ❤️ for Zanzibar's Heritage
