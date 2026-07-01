import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(_getInitialThemeMode());

  static ThemeMode _getInitialThemeMode() {
    try {
      final modeStr = SharedPrefsService.instance.themeMode;
      return _parseMode(modeStr);
    } catch (_) {
      return ThemeMode.light;
    }
  }

  static ThemeMode _parseMode(String modeStr) {
    switch (modeStr) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String modeStr;
    switch (mode) {
      case ThemeMode.dark:
        modeStr = 'dark';
        break;
      case ThemeMode.system:
        modeStr = 'system';
        break;
      case ThemeMode.light:
        modeStr = 'light';
        break;
    }
    await SharedPrefsService.instance.setThemeMode(modeStr);
    emit(mode);
  }
}
