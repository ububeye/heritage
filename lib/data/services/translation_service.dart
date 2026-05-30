import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  // Google Cloud Translation API key - should be stored securely
  // For production, use environment variables or secure storage
  static const String _apiKey = 'YOUR_GOOGLE_TRANSLATION_API_KEY';

  // Supported languages for translation
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'sw': 'Swahili',
    'fr': 'French',
    'de': 'German',
    'ar': 'Arabic',
    'it': 'Italian',
    'es': 'Spanish',
  };

  /// Translates text from source language to target language
  /// Returns null if translation fails
  Future<String?> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    if (text.isEmpty) return null;
    if (targetLanguage == sourceLanguage) return text;

    try {
      final url = Uri.parse(
        'https://translation.googleapis.com/language/translate/v2?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': sourceLanguage,
          'target': targetLanguage,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['translations'][0]['translatedText'];
      }
      return null;
    } catch (e) {
      print('Translation error: $e');
      return null;
    }
  }

  /// Translates a map of texts (e.g., descriptions in multiple languages)
  /// Skips already translated texts
  Future<Map<String, String>> translateMissing({
    required Map<String, String> existingTranslations,
    required String baseLanguage,
    required List<String> targetLanguages,
  }) async {
    final result = Map<String, String>.from(existingTranslations);

    for (final targetLang in targetLanguages) {
      // Skip if already exists
      if (result.containsKey(targetLang) && result[targetLang]!.isNotEmpty) {
        continue;
      }

      // Skip if same as base language
      if (targetLang == baseLanguage) {
        continue;
      }

      // Get the base text to translate
      final baseText = result[baseLanguage] ?? '';

      if (baseText.isNotEmpty) {
        final translated = await translate(
          text: baseText,
          targetLanguage: targetLang,
          sourceLanguage: baseLanguage,
        );

        if (translated != null) {
          result[targetLang] = translated;
        }
      }
    }

    return result;
  }

  /// Batch translate multiple fields
  /// [fields] is a map of field name to text to translate
  /// Returns a map of field name to translated texts per language
  Future<Map<String, Map<String, String>>> batchTranslate({
    required Map<String, String> baseTexts, // field name -> text in base language
    required String baseLanguage,
    required List<String> targetLanguages,
  }) async {
    final result = <String, Map<String, String>>{};

    for (final entry in baseTexts.entries) {
      final fieldName = entry.key;
      final baseText = entry.value;

      // Initialize with base text
      result[fieldName] = {baseLanguage: baseText};

      // Translate to each target language
      for (final targetLang in targetLanguages) {
        if (targetLang == baseLanguage) continue;

        if (baseText.isNotEmpty) {
          final translated = await translate(
            text: baseText,
            targetLanguage: targetLang,
            sourceLanguage: baseLanguage,
          );

          if (translated != null) {
            result[fieldName]![targetLang] = translated;
          }
        }
      }
    }

    return result;
  }
}
