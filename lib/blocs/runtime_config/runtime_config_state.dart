part of 'runtime_config_cubit.dart';

/// Mirror of [RuntimeConfigSnapshot] for the cubit. Same fields, same
/// defaults; lives in the cubit file so adding a `package:` import here
/// doesn't drag cubit-internal types into the state file.
class RuntimeConfigState {
  const RuntimeConfigState({
    required this.freeAudioMaxSeconds,
    required this.orsApiKey,
    required this.maintenanceMode,
    required this.googleSignInEnabled,
  });

  factory RuntimeConfigState.initial() => const RuntimeConfigState(
    freeAudioMaxSeconds: 30,
    orsApiKey: '',
    maintenanceMode: false,
    googleSignInEnabled: false,
  );

  final int freeAudioMaxSeconds;
  final String orsApiKey;
  final bool maintenanceMode;
  final bool googleSignInEnabled;

  RuntimeConfigState copyWith({
    int? freeAudioMaxSeconds,
    String? orsApiKey,
    bool? maintenanceMode,
    bool? googleSignInEnabled,
  }) {
    return RuntimeConfigState(
      freeAudioMaxSeconds: freeAudioMaxSeconds ?? this.freeAudioMaxSeconds,
      orsApiKey: orsApiKey ?? this.orsApiKey,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      googleSignInEnabled: googleSignInEnabled ?? this.googleSignInEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RuntimeConfigState &&
      other.freeAudioMaxSeconds == freeAudioMaxSeconds &&
      other.orsApiKey == orsApiKey &&
      other.maintenanceMode == maintenanceMode &&
      other.googleSignInEnabled == googleSignInEnabled;

  @override
  int get hashCode => Object.hash(
        freeAudioMaxSeconds,
        orsApiKey,
        maintenanceMode,
        googleSignInEnabled,
      );
}
