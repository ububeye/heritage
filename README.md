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
- **Auto-translation**: Google Cloud Translation API integration

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
| Maps | OpenStreetMap + Leaflet.js |
| Translation | Google Cloud Translation API |
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
4. Download `google-services.json` → `android/app/`

### 2. Cloudinary Setup
1. Create Cloudinary account
2. Create upload preset (unsigned)
3. Update `cloudinary_service.dart` with your credentials

### 3. Google Cloud Translation (Optional)
1. Enable Cloud Translation API
2. Get API key
3. Update `translation_service.dart`

### 4. Run the App
```bash
flutter pub get
flutter run
```

## Maps

The app uses two map libraries, chosen for their respective strengths:

- **`flutter_map` + OpenStreetMap** (free, no API key) is used for all browse and admin screens:
  - Explore screen's "Map view" (taps a marker to open site detail)
  - "View on Map" screen for a single site (with a Navigate FAB)
  - Admin "Add Site" and "Edit Site" location pickers (drag the pin, tap to drop a new one, "My location" button snaps to GPS)
- **`google_maps_flutter`** is used in the live-navigation screen (`NavigationScreen`) for GPS-follow + polylines. **It requires a Google Maps Android/iOS API key configured in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift` for tiles to render.** Without a key, the map shows a blank area with a friendly explanation banner, but the navigation logic (distance, ETA, arrival detection via `Geolocator`) still works correctly.

### OSM tile usage

`flutter_map` fetches tiles from `https://tile.openstreetmap.org/`. The OpenStreetMap Foundation's [tile usage policy](https://operations.osmfoundation.org/policies/tiles/) allows light use with a descriptive `User-Agent` (we set `com.example.stone_town_heritage_vt_guide`) but prohibits heavy production traffic. For a final-year demo this is well within limits. For production deployment, switch to a paid tile provider (Stadia Maps, Mapbox, etc.) — only [lib/ui/widgets/heritage_map.dart](lib/ui/widgets/heritage_map.dart) would need to change.

## Screenshots

- Welcome Screen with language selector
- Home with site grid
- Explore with search and filters
- Site detail with gallery and audio
- Navigation with distance/ETA
- Admin Dashboard with stats
- Admin Site Management
- Admin User Management

## License

MIT License - See LICENSE file

---

Built with ❤️ for Zanzibar's Heritage
