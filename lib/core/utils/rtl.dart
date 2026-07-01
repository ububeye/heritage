import 'package:flutter/material.dart';

/// Returns true when the given language code is read right-to-left.
///
/// Today this is just Arabic, but is left as a separate predicate so other
/// RTL locales (Hebrew, Urdu, Persian) can be added in one place.
bool localeIsRtl(String code) {
  switch (code) {
    case 'ar':
    case 'he':
    case 'fa':
    case 'ur':
      return true;
    default:
      return false;
  }
}

/// Resolves the appropriate [TextDirection] for the given locale code.
TextDirection directionFor(String code) {
  return localeIsRtl(code) ? TextDirection.rtl : TextDirection.ltr;
}
