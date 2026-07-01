import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'data/services/shared_prefs_service.dart';
import 'data/services/tile_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Enable edge-to-edge mode so the system navigation bar becomes transparent
  // and follows the theme colors underneath.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Let the OS and AppTheme handle system UI colors automatically
  // (Removed hardcoded SystemUIOverlayStyle to support Dark Mode)

  await Firebase.initializeApp();
  await SharedPrefsService.getInstance();

  // Tile cache init is fire-and-forget — the cache is opportunistic
  // and the map still works even if the directory can't be created.
  // The provider falls back to a plain NetworkTileProvider in that case.
  // ignore: unawaited_futures
  TileCacheService.bootstrap();

  runApp(const StoneTownApp());
}
