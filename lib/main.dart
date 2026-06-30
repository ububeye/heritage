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

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp();
  await SharedPrefsService.getInstance();

  // Tile cache init is fire-and-forget — the cache is opportunistic
  // and the map still works even if the directory can't be created.
  // The provider falls back to a plain NetworkTileProvider in that case.
  // ignore: unawaited_futures
  TileCacheService.bootstrap();

  runApp(const StoneTownApp());
}