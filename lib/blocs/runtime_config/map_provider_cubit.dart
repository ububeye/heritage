import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_constants.dart';
import '../../data/services/shared_prefs_service.dart';

/// Read/write cubit over `SharedPrefsService.mapProvider`.
///
/// The cubit is intentionally thin: the source of truth remains the
/// shared-prefs singleton, the cubit just gives callers a `BlocBuilder`
/// surface so the settings tile and the `HeritageMap` body can stay in
/// sync without a `setState()` ping-pong.
///
/// Without an `orsApiKey`, only `mapProviderOpen` is selectable; once an
/// admin enters a key the ORS provider becomes available and pushes here.
class MapProviderCubit extends Cubit<String> {
  MapProviderCubit()
      : super(SharedPrefsService.instance.mapProvider);

  /// Current provider IDs the user can pick from given the live runtime
  /// config. When a Google Maps key is configured the `google` option
  /// appears; otherwise it's hidden to avoid an unconfigured tile feed.
  List<String> get available {
    final apiKey = AppConstants.googleMapsApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      return const [
        AppConstants.mapProviderOpen,
        AppConstants.mapProviderGoogle,
      ];
    }
    return const [AppConstants.mapProviderOpen];
  }

  /// Persist the selection and emit the new value.
  Future<void> select(String provider) async {
    if (provider == state) return;
    await SharedPrefsService.instance.setMapProvider(provider);
    emit(provider);
  }
}
