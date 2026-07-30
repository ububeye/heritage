import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/language_meta.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/models/audio_state.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

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
        audioState.wasTruncated &&
        !isPremium &&
        audioState.duration > Duration.zero;

    return Container(
      padding: AppInsets.card,
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            // Bottom-bar shadow — theme-aware.
            color: context.semanticColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BlocBuilder<LocalizationCubit, LocalizationState>(
          // Single BlocBuilder for the whole bar — previously only the
          // replay tooltip subscribed, so a language switch during
          // playback left the rest of the bar with whatever labels it
          // was built with. Now everything (play/pause label, replay
          // tooltip) updates together.
          builder: (context, locState) {
            final playPauseLabel =
                locState.translations[isPlaying ? 'pause' : 'play'] ??
                (isPlaying ? 'Pause' : 'Play');
            return Row(
              children: [
                // Circular play / pause button — accent fill, dark icon.
                // Wrapped in Semantics so TalkBack / VoiceOver can read
                // what the button does (WCAG 2.1 SC 4.1.2). The label
                // flips between 'Play' and 'Pause' in the active UI
                // language. Localized tooltip pops up on long-press /
                // hover for sighted users.
                Semantics(
                  label: playPauseLabel,
                  button: true,
                  child: GestureDetector(
                    onTap: onPlayPause,
                    child: Tooltip(
                      message: playPauseLabel,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: AppRadius.avatarBorder,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 32,
                          color: scheme.onSecondary,
                        ),
                      ),
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
                      // While the engine is preparing (speak() dispatching,
                      // voice switching, first progress callback not yet
                      // fired) render an indeterminate bar instead of a
                      // zero-fill determinate one — the previous behaviour
                      // looked like a frozen 00:00 / 00:00 bar for the
                      // first ~50-100 ms of every play.
                      if (audioState.isLoading)
                        LinearProgressIndicator(
                          backgroundColor:
                              Theme.of(context).colorScheme.outline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          minHeight: 4,
                        )
                      else
                        LinearProgressIndicator(
                          value: audioState.progress.clamp(0.0, 1.0),
                          backgroundColor:
                              Theme.of(context).colorScheme.outline,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.secondary,
                          ),
                          minHeight: 4,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        audioState.isLoading
                            ? 'Loading…'
                            : '${audioState.positionText} / ${audioState.durationText}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (showReplay)
                  IconButton(
                    tooltip: locState.translations['replay'] ?? 'Replay',
                    onPressed: onReplay,
                    icon: Icon(
                      Icons.replay,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            );
          },
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
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: AppInsets.pillTight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LanguageMeta.flag(code), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              LanguageMeta.name(code),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
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
      padding: AppInsets.pillTiny,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: AppRadius.bannerBorder,
      ),
      child: Text(
        'PREVIEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }
}
