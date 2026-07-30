part of 'runtime_config_cubit.dart';

/// Mirror of [RuntimeConfigSnapshot] for the cubit. Same fields, same
/// defaults; lives in the cubit file so adding a `package:` import here
/// doesn't drag cubit-internal types into the state file.
class RuntimeConfigState {
  const RuntimeConfigState({
    required this.freeAudioMaxSeconds,
    required this.orsApiKey,
    required this.maintenanceMode,
  });

  factory RuntimeConfigState.initial() => const RuntimeConfigState(
    freeAudioMaxSeconds: 30,
    orsApiKey: '',
    maintenanceMode: false,
  );

  final int freeAudioMaxSeconds;
  final String orsApiKey;
  final bool maintenanceMode;

  RuntimeConfigState copyWith({
    int? freeAudioMaxSeconds,
    String? orsApiKey,
    bool? maintenanceMode,
  }) {
    return RuntimeConfigState(
      freeAudioMaxSeconds: freeAudioMaxSeconds ?? this.freeAudioMaxSeconds,
      orsApiKey: orsApiKey ?? this.orsApiKey,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RuntimeConfigState &&
      other.freeAudioMaxSeconds == freeAudioMaxSeconds &&
      other.orsApiKey == orsApiKey &&
      other.maintenanceMode == maintenanceMode;

  @override
  int get hashCode =>
      Object.hash(freeAudioMaxSeconds, orsApiKey, maintenanceMode);
}
