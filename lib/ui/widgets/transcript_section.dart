import 'package:flutter/material.dart';
import '../../core/utils/language_meta.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_durations.dart';

/// Collapsible "Show transcript" widget. Used on the site detail screen
/// below the description so deaf / quiet-environment users can read
/// along with the audio. Renders the *spoken* text in the *audio*
/// language (which can differ from the UI language), and exposes a
/// trailing ellipsis on free-tier previews to mirror the audio cut.
class TranscriptSection extends StatefulWidget {
  const TranscriptSection({
    super.key,
    required this.title,
    required this.text,
    required this.audioLanguageCode,
    this.defaultExpanded = false,
    this.truncated = false,
  });

  final String title;
  final String text;
  final String audioLanguageCode;
  final bool defaultExpanded;

  /// True for free-tier playback where the text was cut at a sentence
  /// boundary. Renders a trailing ellipsis so the user sees the same
  /// boundary the audio played to.
  final bool truncated;

  @override
  State<TranscriptSection> createState() => _TranscriptSectionState();
}

class _TranscriptSectionState extends State<TranscriptSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandCurve;

  @override
  void initState() {
    super.initState();
    // Construct the controller in initState so that the TickerProvider can
    // safely look up the surrounding TickerMode while the element is still
    // mounted. Doing this as a `late final` lazy initializer would defer
    // construction until first access — which can be `dispose()` if the
    // widget is removed before its first build (e.g. no transcript text),
    // and that would throw "deactivated widget's ancestor is unsafe".
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.navigation,
      value: widget.defaultExpanded ? 1.0 : 0.0,
    );
    _expandCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_controller.value == 0.0) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = widget.text.trim().isNotEmpty;

    if (!hasText) {
      // No audio has been played yet — render nothing rather than an
      // empty section. The widget shows up the moment the user hits play.
      return const SizedBox.shrink();
    }

    final trailingText =
        widget.truncated ? '${widget.text.trimRight()}…' : widget.text;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tappable header — title, language flag, and a rotating chevron.
          InkWell(
            onTap: _toggle,
            borderRadius: AppRadius.mdBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.subtitles_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  Text(
                    LanguageMeta.flag(widget.audioLanguageCode),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_expandCurve),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable body. SizeTransition handles the height tween;
          // the inner child fades in once the animation reaches ~50%.
          SizeTransition(
            axisAlignment: -1.0,
            sizeFactor: _expandCurve,
            child: FadeTransition(
              opacity: _expandCurve,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SelectableText(
                  trailingText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
