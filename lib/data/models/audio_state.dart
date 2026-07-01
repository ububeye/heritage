import 'package:equatable/equatable.dart';

class AudioState extends Equatable {

  const AudioState({
    this.isPlaying = false,
    this.isPaused = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.languageCode = 'en',
    this.isLoading = false,
    this.errorMessage,
  });
  final bool isPlaying;
  final bool isPaused;
  final Duration position;
  final Duration duration;
  final String languageCode;
  final bool isLoading;
  final String? errorMessage;

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  String get positionText => _formatDuration(position);
  String get durationText => _formatDuration(duration);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  AudioState copyWith({
    bool? isPlaying,
    bool? isPaused,
    Duration? position,
    Duration? duration,
    String? languageCode,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      languageCode: languageCode ?? this.languageCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isPlaying,
        isPaused,
        position,
        duration,
        languageCode,
        isLoading,
        errorMessage,
      ];
}
