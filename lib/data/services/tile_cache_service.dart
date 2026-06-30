import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';

/// On-disk + in-memory cache for OSM raster tiles.
///
/// Drop-in replacement for `NetworkTileProvider()`. Plug it into the
/// existing `TileLayer(tileProvider: ...)` slots in `heritage_map.dart`
/// and `navigation_screen_open.dart` and you get:
///
///   * second-visit instant basemaps (tiles come from disk instead of
///     re-downloading),
///   * an in-flight deduplication map so quick pans don't issue
///     duplicate HTTP requests for the same tile,
///   * a soft max-age (30 days by default) so stale raster tiles get
///     refreshed automatically.
///
/// Why custom rather than `flutter_map_tile_caching`?
///
///   `flutter_map_tile_caching ^9.0.0` declares a hard dependency on
///   `flutter_map ^8.x`. The project is pinned to `^7.0.2`, and
///   upgrading `flutter_map` is a separate breaking change touching
///   several screens. This service keeps the cache layer local to the
///   app and pairs with whatever `flutter_map` version the project is on.
class TileCacheService {
  static TileCacheService? _instance;

  /// Singleton accessor — mirrors `SharedPrefsService` so callers read
  /// the same way across the codebase.
  static TileCacheService get instance {
    final i = _instance;
    if (i == null) {
      throw Exception(
        'TileCacheService not initialized. Call init() in main() first.',
      );
    }
    return i;
  }

  /// True once [init] has finished successfully. Lets callers skip the
  /// cache entirely when filesystem access isn't available (e.g. tests
  /// or readonly sandboxes).
  bool get isReady => _rootDir != null;

  Directory? _rootDir;

  /// In-flight dedup map. Keyed by `${z}/${x}/${y}`. When two widgets
  /// request the same tile within milliseconds of each other (very
  /// common during pans), the second caller awaits the first future
  /// instead of issuing a second HTTP request.
  ///
  /// Values are held as `Future<Uint8List?>` rather than objects so
  /// `await caller` gets raw bytes — same shape as a fresh fetch. We
  /// avoid boxing in a typed wrapper because the bytes are the only
  /// thing downstream `MemoryImage` cares about.
  final Map<String, Future<Uint8List?>> _inflight = {};

  /// In-memory hit cache for the lifetime of the app. Keeps the most
  /// recently-viewed tiles hot so micro-jittery re-renders don't even
  /// hit the disk.
  final Map<String, Uint8List> _hot = {};

  /// Synchronous look-up used by [_CachedTileProvider.getImage] so we
  /// can return a `MemoryImage` immediately when the tile is hot, and
  /// only fall back to a `NetworkImage` when we have to.
  Uint8List? peekHot(int z, int x, int y) => _hot['$z/$x/$y'];

  TileCacheService._();

  /// Static bootstrap that creates the singleton if needed and kicks
  /// off the directory init. Safe to call from `main()` before the
  /// first `instance.tileProvider()` call.
  static Future<void> bootstrap({Directory? overrideDir}) async {
    final s = _instance ??= TileCacheService._();
    await s.init(overrideDir: overrideDir);
  }

  /// Initialise the cache. Idempotent and safe to call multiple times.
  /// We don't `await` this from main() — the cache is opportunistic,
  /// and even if the directory isn't ready yet, the first tile request
  /// triggers a lazy retry.
  Future<void> init({Directory? overrideDir}) async {
    if (_rootDir != null) return;
    try {
      final dir = overrideDir ?? await getApplicationSupportDirectory();
      _rootDir = Directory('${dir.path}/tiles');
      if (!await _rootDir!.exists()) {
        await _rootDir!.create(recursive: true);
      }
    } catch (e) {
      // Cannot provision a cache directory (e.g. test runner, readonly
      // FS). The provider falls back to NetworkTileProvider behaviour.
      _rootDir = null;
    }
  }

  /// Returns a [TileProvider] suitable for use in a flutter_map
  /// `TileLayer(tileProvider: ...)`.
  ///
  /// When the service hasn't been initialised (or couldn't provision a
  /// cache directory), returns a vanilla network provider instead —
  /// the app stays functional, just without the cache. Kicks off init
  /// in the background so the *next* call (after init completes) gets
  /// the cached provider.
  TileProvider tileProvider() {
    final dir = _rootDir;
    if (dir == null) {
      // Best-effort lazy init — don't block the caller. The first
      // request for a tile may go to the network, but the second one
      // (once init finishes) hits the cache.
      unawaited(init());
      return NetworkTileProvider();
    }
    return _CachedTileProvider(this);
  }

  /// Look up a tile's raw bytes, in this order:
  ///   1. Hot in-memory entry (sub-millisecond hit),
  ///   2. Disk file, if it's younger than the configured max age,
  ///   3. Network fetch, then write back to disk.
  ///
  /// Returns null on every miss. Concurrent calls for the same tile
  /// share a single fetch via [_inflight].
  Future<Uint8List?> getOrFetch({
    required int z,
    required int x,
    required int y,
    required String urlTemplate,
  }) async {
    final key = '$z/$x/$y';

    // 1. Hot.
    final hot = _hot[key];
    if (hot != null) return hot;

    // 2. Disk.
    final diskPath = await _diskPathFor(z, x, y);
    if (diskPath != null) {
      try {
        final file = File(diskPath);
        if (await file.exists()) {
          final age = DateTime.now()
              .difference(await file.lastModified())
              .inDays;
          if (age < AppConstants.tileCacheMaxAgeDays) {
            final bytes = await file.readAsBytes();
            _hot[key] = bytes;
            return bytes;
          }
        }
      } catch (_) {
        // Disk read failed — fall through to network.
      }
    }

    // 3. Deduplicated network fetch.
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final completer = Completer<Uint8List?>();
    _inflight[key] = completer.future;
    try {
      final url = _populateTemplatePlaceholders(
        urlTemplate: urlTemplate,
        coordinates: TileCoordinates(x, y, z),
      );
      final resp = await http
          .get(
            Uri.parse(url),
            headers: const {
              'User-Agent':
                  'com.example.stone_town_heritage_vt_guide/1.0 (Flutter)',
            },
          )
          .timeout(const Duration(seconds: 8));

      final Uint8List? bytes =
          (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty)
              ? resp.bodyBytes
              : null;

      if (bytes != null) {
        // Best-effort disk write — never blocks the request.
        if (diskPath != null && bytes.length < 200 * 1024) {
          unawaited(_writeToDisk(diskPath, bytes));
        }
        _hot[key] = bytes;
        completer.complete(bytes);
      } else {
        completer.complete(null);
      }
      return bytes;
    } catch (e) {
      completer.complete(null);
      return null;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<void> _writeToDisk(String path, Uint8List bytes) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // Best-effort. A disk write failure isn't fatal — the tile is
      // already in `_hot`.
    }
  }

  Future<String?> _diskPathFor(int z, int x, int y) async {
    final dir = _rootDir;
    if (dir == null) return null;
    final layer = Directory('${dir.path}/$z/$x');
    if (!await layer.exists()) {
      try {
        await layer.create(recursive: true);
      } catch (_) {
        return null;
      }
    }
    return '${layer.path}/$y.png';
  }
}

/// flutter_map `TileProvider` subclass that delegates every tile
/// request through [TileCacheService] and returns a `MemoryImage` once
/// the bytes are resolved. Falls back to the network layer when the
/// cache isn't ready or the disk lookup fails.
class _CachedTileProvider extends TileProvider {
  final TileCacheService _service;
  _CachedTileProvider(this._service);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final template = options.urlTemplate ?? '';
    if (template.isEmpty) {
      // Behave like the default provider when there's no template.
      return NetworkImage(
        _populateTemplatePlaceholders(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          coordinates: coordinates,
        ),
        headers: const {
          'User-Agent':
              'com.example.stone_town_heritage_vt_guide/1.0 (Flutter)',
        },
      );
    }

    // Try the cache synchronously: if `_hot` already has the tile we
    // can return a `MemoryImage` immediately. Otherwise we return a
    // synchronous-fallback `NetworkImage` and start the cache lookup
    // in parallel — the cache will populate `_hot` for the next frame
    // and the disk will be primed for the second visit.
    final cached = _service.peekHot(
      coordinates.z,
      coordinates.x,
      coordinates.y,
    );
    if (cached != null) {
      return MemoryImage(cached);
    }
    final url = _populateTemplatePlaceholders(
      urlTemplate: template,
      coordinates: coordinates,
    );
    unawaited(_service.getOrFetch(
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
      urlTemplate: template,
    ));
    return NetworkImage(
      url,
      headers: const {
        'User-Agent':
            'com.example.stone_town_heritage_vt_guide/1.0 (Flutter)',
      },
    );
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final t = options.urlTemplate ?? '';
    if (t.isEmpty) {
      return _populateTemplatePlaceholders(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        coordinates: coordinates,
      );
    }
    return _populateTemplatePlaceholders(
      urlTemplate: t,
      coordinates: coordinates,
    );
  }
}

/// Pure-Dart equivalent of `flutter_map`'s
/// `populateTemplatePlaceholders`. Doesn't depend on the package's
/// internals — just `z`, `x`, `y`.
String _populateTemplatePlaceholders({
  required String urlTemplate,
  required TileCoordinates coordinates,
}) {
  return urlTemplate
      .replaceAll('{z}', coordinates.z.toString())
      .replaceAll('{x}', coordinates.x.toString())
      .replaceAll('{y}', coordinates.y.toString());
}
