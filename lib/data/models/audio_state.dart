import 'package:equatable/equatable.dart';

/// Snapshot of where playback was paused, used to resume on Android.
/// `flutter_tts.pause()` is iOS-only; on Android we stop the engine and
/// restart from this saved offset when the user resumes.
class PausedResumePoint extends Equatable {
  const PausedResumePoint({
    required this.text,
    required this.charOffset,
  });
  final String text;
  final int charOffset;

  @override
  List<Object?> get props => [text, charOffset];
}

class AudioState extends Equatable {

  const AudioState({
    this.isPlaying = false,
    this.isPaused = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.languageCode = 'en',
    this.isLoading = false,
    this.errorMessage,
    this.wasTruncated = false,
    this.maxDurationSeconds,
    this.spokenText = '',
    this.pausedResumePoint,
  });
  final bool isPlaying;
  final bool isPaused;
  final Duration position;
  final Duration duration;
  final String languageCode;
  final bool isLoading;
  final String? errorMessage;

  /// True for free-tier users when the narration was cut at a sentence
  /// boundary because it would have exceeded the per-session time cap.
  /// UI uses this to surface an upgrade prompt instead of the silent
  /// mid-clause stop the old `_truncateText` produced.
  final bool wasTruncated;

  /// The time cap that produced [wasTruncated], or null for unlimited
  /// (premium) playback. Surfaced to the UI so the badge can read
  /// "30-second preview" rather than hard-coding the number.
  final int? maxDurationSeconds;

  /// The exact string the engine is speaking (or was speaking before a
  /// pause). For free-tier playback this is the sentence-bounded chunk,
  /// not the full description — used by the transcript view to render
  /// the spoken text in the audio language.
  final String spokenText;

  /// Snapshot taken at pause time so the Android path can restart from
  /// the right offset. Null on iOS where the engine keeps its own position.
  final PausedResumePoint? pausedResumePoint;

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
    bool? wasTruncated,
    int? maxDurationSeconds,
    String? spokenText,
    PausedResumePoint? pausedResumePoint,
    bool clearPausedResumePoint = false,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      languageCode: languageCode ?? this.languageCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      wasTruncated: wasTruncated ?? this.wasTruncated,
      maxDurationSeconds: maxDurationSeconds ?? this.maxDurationSeconds,
      spokenText: spokenText ?? this.spokenText,
      pausedResumePoint: clearPausedResumePoint
          ? null
          : (pausedResumePoint ?? this.pausedResumePoint),
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
        wasTruncated,
        maxDurationSeconds,
        spokenText,
        pausedResumePoint,
      ];
}
