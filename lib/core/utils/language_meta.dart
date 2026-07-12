/// Single source of truth for the seven TTS/UI languages supported by the
/// app: display names and flag emojis. Three screens used to ship their
/// own copies of these maps; consolidating here keeps the picker, the
/// audio player, and the SnackBar messages from drifting.
///
/// Codes match `AppConstants.ttsLanguages` / `AppConstants.uiLanguages`.
class LanguageMeta {
  LanguageMeta._();

  /// Localized display name in the *language itself* — what the user sees
  /// when picking an audio language ("Français" not "French").
  static const Map<String, String> displayNames = {
    'en': 'English',
    'sw': 'Kiswahili',
    'fr': 'Français',
    'de': 'Deutsch',
    'ar': 'العربية',
    'it': 'Italiano',
    'es': 'Español',
  };

  /// Flag emoji for the language — paired with the display name on chips
  /// and pickers. Falls back to a globe for any code outside the map.
  static const Map<String, String> flags = {
    'en': '🇬🇧',
    'sw': '🇹🇿',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'ar': '🇸🇦',
    'it': '🇮🇹',
    'es': '🇪🇸',
  };

  /// Display name for [code], or the raw code if unmapped.
  static String name(String code) => displayNames[code] ?? code;

  /// Flag emoji for [code], or a globe if unmapped.
  static String flag(String code) => flags[code] ?? '🌐';
}