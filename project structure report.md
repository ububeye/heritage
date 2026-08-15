# Stone Town Heritage VT Guide - Project Structure Report

This report documents the entire directory and file structure of the Stone Town Heritage VT Guide application, detailing the purpose of each directory and file.

## 1. Root Configuration and Metadata Files

- `pubspec.yaml`: Core configuration file for Flutter. It defines project dependencies (Firebase, Flutter Bloc, Maps, TTS, UI components), asset declarations, fonts, and project metadata (version, description).
- `pubspec.lock`: Auto-generated lockfile pinning exact versions of all dependencies resolved from `pubspec.yaml`.
- `README.md`: Project documentation file providing an overview of the application and instructions.
- `firebase.json`: Configuration file for Firebase services (Hosting, Functions, etc.).
- `firestore.indexes.json`: Defines composite indexes required for querying Cloud Firestore data.
- `firestore.rules`: Security rules for Firebase Cloud Firestore, determining who can read and write to the database.
- `analysis_options.yaml`: Configures the Dart analyzer to enforce coding standards, linting rules, and strict typing.
- `.firebaserc`: Links the local project directory to a specific Firebase project ID.
- `.gitignore`: Specifies intentionally untracked files that Git should ignore (e.g., build outputs, IDE configs).
- `stone_town_heritage_vt_guide.iml`: IntelliJ IDEA module configuration file.
- `.metadata`: A Flutter-managed file used by flutter tools to track project properties.
- `completion.md` & `finalized.md`: Project documentation and status files tracking progress and finalized requirements.
- `.flutter-plugins` & `.flutter-plugins-dependencies`: Auto-generated files that track native plugin dependencies across platforms.

## 2. Assets Directory (`assets/`)

Contains static resources bundled with the app.

- **`assets/icons/`**
  - `icon.jpeg`: The primary application icon used for generating launcher icons for Android/iOS.
- **`assets/images/`**
  - `logo.jpeg`: The app's logo image used in splash screens, login, or UI headers.
  - `.gitkeep`: Empty file to ensure the directory is tracked by Git.
- **`assets/localization/`**
  - `en.json`: English translation strings for internationalization.
  - `sw.json`: Swahili translation strings for internationalization.

## 3. Source Code (`lib/`)

The core source code of the Flutter application.

### Entry Point
- `main.dart`: The main entry point of the Flutter app. Initializes Firebase, dependencies, and runs the root widget.
- `app.dart`: The root `MaterialApp` widget setup. It configures routing, theme, localization, and global Bloc providers.

### State Management (`lib/blocs/`)
Contains Cubits/Blocs for managing state across different features using `flutter_bloc`.
- **`activity/`** (`activity_cubit.dart`, `activity_state.dart`): Manages state related to user activities or gamification.
- **`auth/`** (`auth_cubit.dart`, `auth_state.dart`): Handles user authentication state (login, registration, logout) with Firebase.
- **`explore/`** (`explore_cubit.dart`): Manages the state for exploring different heritage sites.
- **`favorites/`** (`favorites_cubit.dart`): Manages the state of the user's bookmarked or favorite sites.
- **`language/`** (`language_cubit.dart`): Handles language switching (English/Swahili) state.
- **`localization/`** (`localization_cubit.dart`): Integrates with the actual localization engine to provide translated strings to the UI.
- **`navigation/`** (`navigation_cubit.dart`, `navigation_state.dart`): Manages custom in-app routing or map navigation states.
- **`premium/`** (`premium_cubit.dart`, `premium_state.dart`): Manages in-app purchases, billing provider status, and premium unlocking.
- **`runtime_config/`** (`runtime_config_cubit.dart`, `runtime_config_state.dart`): Manages dynamic configuration flags or remotely fetched configs.
- **`site_detail/`** (`site_detail_cubit.dart`, `site_detail_state.dart`): Manages the complex state of a single heritage site's detail view (audio playback, expanded text).
- **`site_list/`** (`site_list_cubit.dart`, `site_list_state.dart`): Manages the fetching, filtering, and displaying of multiple heritage sites.
- **`theme/`** (`theme_cubit.dart`): Handles dynamic theme switching (e.g., light mode/dark mode).
- **`user/`** (`user_cubit.dart`): Manages user profile data, settings, and preferences.

### Core Utilities (`lib/core/`)
- **`constants/`**
  - `app_constants.dart`: Global static constants, API keys, magic numbers, or predefined layout constraints.
- **`theme/`**
  - `app_breakpoints.dart`: Breakpoint values for responsive design.
  - `app_durations.dart`: Standardized animation durations.
  - `app_palette.dart`: Core color palette definitions.
  - `app_radius.dart`: Standardized border radii for widgets.
  - `app_semantic_colors.dart`: Semantic colors (error, success, warning).
  - `app_shadows.dart`: Definitions for standard box shadows/elevations.
  - `app_spacing.dart`: Standardized padding and margin values.
  - `app_text_styles.dart`: Typography scales and font styling.
  - `app_theme.dart`: The aggregated `ThemeData` objects for light and dark modes.
- **`utils/`**
  - `debouncer.dart`: Utility to throttle/debounce frequent events (like search typing).
  - `distance_calculator.dart`: Mathematical utility to calculate geographic distances between coordinates.
  - `language_meta.dart`: Metadata mappings for language codes and names.
  - `nav_guard.dart`: Route guards protecting screens that require authentication or premium access.
  - `polyline_snap.dart`: Utility to snap map paths to actual roads or valid paths.
  - `rtl.dart`: Utility to handle Right-to-Left text directionality (if needed for languages like Arabic).
  - `stone_town_bounds.dart`: Geographical bounds (Lat/Lng) specifically for Stone Town.
  - `unguja_bounds.dart`: Geographical bounds for the broader Unguja island.

### Data Layer (`lib/data/`)
- **`models/`**
  - `activity_model.dart`: Data structure for a user activity/log.
  - `audio_state.dart`: Data structure capturing the current state of TTS or audio playback.
  - `navigation_state.dart`: Data structure capturing real-time navigation/routing info.
  - `site_model.dart`: Core data model representing a heritage site (name, description, location, images).
  - `user_model.dart`: Data model for an authenticated user.
- **`repositories/`**
  - `site_repository.dart`: Abstracts data fetching for sites, deciding whether to hit local cache or Firestore.
- **`services/`**
  - `auth_service.dart`: Interacts directly with Firebase Auth.
  - `billing_provider.dart`: Interface for in-app purchase logic.
  - `fake_billing_provider.dart`: Mock implementation of billing for testing.
  - `cloudinary_service.dart`: Integrates with Cloudinary for fetching or uploading optimized images.
  - `firestore_service.dart`: Handles generic CRUD operations with Cloud Firestore.
  - `location_service.dart`: Interfaces with device GPS to get user location via `geolocator`.
  - `route_cache_service.dart`: Caches navigation routes locally to save bandwidth/API calls.
  - `routing_service.dart`: Calculates paths from user location to a destination site.
  - `runtime_config_service.dart`: Fetches remote configurations.
  - `shared_prefs_service.dart`: Manages local key-value storage using `shared_preferences`.
  - `tile_cache_service.dart`: Caches map tiles for offline map viewing.
  - `tts_service.dart`: Handles Text-To-Speech generation using `flutter_tts`.

### User Interface (`lib/ui/`)
- **`screens/`**
  - `detail_screen.dart`: Shows comprehensive details, history, and audio for a specific site.
  - `explore_screen.dart`: The primary discovery screen for finding sites.
  - `favorites_screen.dart`: Displays user's saved/bookmarked sites.
  - `home_screen.dart`: Main dashboard upon login.
  - `login_screen.dart` & `register_screen.dart`: User authentication flows.
  - `maintenance_screen.dart`: Shown when the app is forced offline or requires updating.
  - `navigation_screen_open.dart`: An active routing/navigation map view guiding the user.
  - `onboarding_screen.dart`: First-time user tutorial/intro slides.
  - `payment_sheet.dart` & `premium_offer_screen.dart` & `upgrade_content.dart` & `upgrade_screen.dart`: UI related to upselling and processing premium subscriptions.
  - `settings_screen.dart`: App configuration and preferences view.
  - `site_map_screen.dart`: Interactive map showing all site pins.
  - `splash_screen.dart`: Initial loading screen.
  - `user_profile_screen.dart`: View and edit user profile info.
  - `welcome_screen.dart`: Landing page prior to login/register.
  - **`admin/`**
    - `admin_add_site_screen.dart` & `admin_edit_site_screen.dart`: Forms to create/update sites in Firestore.
    - `admin_analytics_screen.dart`: Dashboard for viewing app usage metrics.
    - `admin_settings_screen.dart`: Super-user configuration.
    - `admin_shell.dart`: Container/scaffold for the admin dashboard.
    - `admin_sites_screen.dart`: List view of all sites for management.
    - `admin_user_management_screen.dart`: UI for managing user roles/bans.
- **`widgets/`** (Reusable UI components)
  - `arrival_overlay.dart`: Pop-up shown when the user reaches a site.
  - `audio_player_bar.dart`: Controls for TTS audio playback.
  - `category_chips.dart`: Filter chips (e.g., "Museum", "Mosque", "Historical").
  - `faq_accordion.dart`: Expandable FAQ widget.
  - `featured_site_card.dart` & `site_card.dart` & `site_card_horizontal.dart`: Different card layouts for displaying a site summary.
  - `heritage_map.dart`: Reusable interactive map component based on `flutter_map`.
  - `home_section_header.dart`: Section titles with "See All" buttons.
  - `language_popup.dart`: Modal to select language.
  - `localized_text.dart`: Widget that automatically translates a given key.
  - `payment_method_icons.dart` & `payment_processing_overlay.dart` & `pricing_card.dart` & `trial_badge.dart` & `upgrade_banner.dart`: Premium-related UI widgets.
  - `rating_stars.dart`: Widget displaying a 1-5 star rating.
  - `search_bar_widget.dart`: Global search input.
  - `transcript_section.dart`: Displays the written text of the audio playback.
  - `user_avatar.dart`: Circular user profile image.
  - **`settings/`**
    - `settings_card.dart`, `settings_dropdown_tile.dart`, `settings_section_title.dart`, `settings_segmented_tile.dart`, `settings_tile.dart`: Standardized rows and tiles for building the settings screen.

## 4. Tests (`test/`)
- `distance_calculator_test.dart`: Unit tests for geocoordinate math.
- `heritage_map_bounds_test.dart`: Tests ensuring map boundaries correctly restrict viewing to Unguja/Stone Town.
- `polyline_snap_test.dart`: Tests for map routing path snapping logic.
- `routing_service_test.dart` & `routing_steps_test.dart`: Unit tests for the routing engine.
- `site_model_route_geometry_test.dart` & `site_model_test.dart`: Tests for parsing and validating the Site data model.
- `widget_test.dart`: Basic smoke test for the Flutter widget tree.
- **`core/`**: Subdirectory meant for additional core logic tests.

## 5. Platform-Specific Generated Directories
These folders are generated by Flutter and contain the native code wrappers required to compile the app for each specific platform. They generally shouldn't be manually modified except for specific native configurations (e.g. permissions, launcher icons, platform-specific integrations).
- **`android/`**: Native Android project. Contains `build.gradle`, `AndroidManifest.xml`, and Java/Kotlin entry points.
- **`ios/`**: Native iOS project (Xcode). Contains `Runner.xcodeproj`, `Info.plist`, and Swift/Objective-C entry points.
- **`web/`**: Native Web project. Contains `index.html` (entry point for web browser) and standard web icons.
- **`windows/`**, **`macos/`**, **`linux/`**: Native desktop projects containing C++/Swift runners for desktop targets.

## 6. Build and Tooling Directories
These directories are internally managed by SDKs and tooling, and are completely tracked via `.gitignore`.
- **`.dart_tool/`**: Used by Dart and Flutter tools to store local caches, generated code, and package configurations.
- **`build/`**: The output directory where Flutter places compiled binaries (APKs, IPAs, web bundles). This directory is ephemeral and ignored by Git.
- **`.git/`**: The internal Git repository directory tracking version history.
- **`.github/`**: Typically contains GitHub Actions workflows for CI/CD pipelines.
- **`.idea/`**: Workspace configuration files for JetBrains IDEs (Android Studio / IntelliJ).
- **`.claude/`**: Likely contains workspace configurations or context files for an AI assistant.
