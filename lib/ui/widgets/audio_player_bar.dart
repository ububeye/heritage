import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/language_meta.dart';
import '../../data/models/audio_state.dart';

/// Bottom-sheet audio player used on the site detail screen.
///
/// Reads everything it needs from [AudioState] + [audioLanguageCode],
/// so it can be driven by any cubit that emits those values. All theme
/// colors flow through `Theme.of(context).colorScheme` so the widget
/// works under both light and dark themes — the Tier-1 surface tint
/// keeps the bar lifted off the scaffold.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({
    super.key,
    required this.audioState,
    required this.audioLanguageCode,
    required this.isPremium,
    required this.onPlayPause,
    required this.onLanguageTap,
    required this.onReplay,
  });

  final AudioState audioState;
  final String audioLanguageCode;
  final bool isPremium;

  /// Tap on the circular play / pause button. The parent decides whether
  /// to call `playAudio`, `pauseAudio`, or `resumeAudio` based on the
  /// current state.
  final VoidCallback onPlayPause;

  /// Tap on the language chip — typically opens the audio-language picker.
  final VoidCallback onLanguageTap;

  /// Tap on the replay button (premium only). Typically stops and
  /// restarts the current chunk.
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = audioState.isPlaying;
    final showReplay = isPremium && audioState.duration > Duration.zero;
    final showPreviewBadge =
        audioState.wasTruncated && !isPremium && audioState.duration > Duration.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Circular play / pause button — accent fill, dark icon.
            GestureDetector(
              onTap: onPlayPause,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 32,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LanguageChip(
                        code: audioLanguageCode,
                        onTap: onLanguageTap,
                      ),
                      if (showPreviewBadge) ...[
                        const SizedBox(width: 6),
                        const _PreviewBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: audioState.progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${audioState.positionText} / ${audioState.durationText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showReplay)
              IconButton(
                tooltip: 'Replay',
                onPressed: onReplay,
                icon: const Icon(Icons.replay, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pill showing the audio language's flag + display name + a chevron.
/// Tapping invokes [onTap].
class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LanguageMeta.flag(code), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              LanguageMeta.name(code),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// "PREVIEW" pill — sits next to the language chip when free-tier
/// playback was cut at a sentence boundary. Lets the user see at a
/// glance why the bar will stop before the full description is read.
class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'PREVIEW',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textOnAccent,
        ),
      ),
    );
  }
}