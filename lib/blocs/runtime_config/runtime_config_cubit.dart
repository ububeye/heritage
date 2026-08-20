import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/runtime_config_service.dart';

part 'runtime_config_state.dart';

/// UI mirror of [RuntimeConfigService]. Subscribes to the service's
/// broadcast stream and re-emits on every persistence write. Setter
/// methods write through the service and let the stream subscription
/// push the new state — we deliberately don't `emit` directly from
/// setters, so a single source of truth (the service) drives the cubit.
///
/// Admin settings tiles read this cubit via `BlocBuilder` / `context.watch`
/// so the UI rebuilds when a value changes. Services outside the widget
/// tree (TtsService, RoutingService) read the service directly — they
/// don't need a cubit because they're not widgets.
class RuntimeConfigCubit extends Cubit<RuntimeConfigState> {
  RuntimeConfigCubit({RuntimeConfigService? service})
    : _service = service ?? RuntimeConfigService.instance,
      super(RuntimeConfigState.initial()) {
    _sub = _service.watch().listen(_onSnapshot);
  }

  final RuntimeConfigService _service;
  late final StreamSubscription<RuntimeConfigSnapshot> _sub;

  void _onSnapshot(RuntimeConfigSnapshot snap) {
    // Guard against late events after close — same pattern as
    // PremiumCubit and LocalizationCubit. Without this, a hot-restart
    // could call `emit` after `close`, throwing from inside Cubit.
    if (isClosed) return;
    emit(
      state.copyWith(
        freeAudioMaxSeconds: snap.freeAudioMaxSeconds,
        orsApiKey: snap.orsApiKey,
        maintenanceMode: snap.maintenanceMode,
        googleSignInEnabled: snap.googleSignInEnabled,
      ),
    );
  }

  Future<void> setFreeAudioMaxSeconds(int seconds) =>
      _service.setFreeAudioMaxSeconds(seconds);

  Future<void> setOrsApiKey(String key) => _service.setOrsApiKey(key);

  Future<void> setMaintenanceMode(bool enabled) =>
      _service.setMaintenanceMode(enabled);

  Future<void> setGoogleSignInEnabled(bool enabled) =>
      _service.setGoogleSignInEnabled(enabled);

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
