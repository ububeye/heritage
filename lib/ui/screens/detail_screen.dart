import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/language_meta.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../blocs/site_detail/site_detail_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../core/utils/nav_guard.dart';
import '../widgets/audio_player_bar.dart';
import '../widgets/transcript_section.dart';
import '../widgets/upgrade_banner.dart';
import '../widgets/rating_stars.dart';
import 'site_map_screen.dart';
import 'upgrade_screen.dart';
import '../../blocs/localization/localization_cubit.dart';

class DetailScreen extends StatefulWidget {

  const DetailScreen({super.key, required this.siteId});
  final String siteId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Defer the load until after the first frame so the InheritedWidget
    // tree (and SiteDetailCubit itself) is settled. initState runs before
    // descendants finish mounting; reading providers here has historically
    // thrown ProviderNotFoundException on cold launch — `mounted` guard
    // backstops the case where the user navigates away before the callback
    // fires.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SiteDetailCubit>().loadSite(widget.siteId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Display name for the audio-language chip — delegates to the
  /// shared LanguageMeta util. Kept as a local shim because the
  /// audio-language picker below uses it in a couple of places.
  String _audioLanguageName(String code) => LanguageMeta.name(code);

  /// Show a modal bottom sheet with the 7 audio languages. Free users see
  /// the 5 premium languages greyed out with a "Premium" badge; tapping a
  /// free language updates the cubit and (if audio is currently playing)
  /// restarts playback in the new language.
  Future<void> _showAudioLanguagePicker(BuildContext context, bool isPremium) async {
    final cubit = context.read<LanguageCubit>();
    final siteDetailCubit = context.read<SiteDetailCubit>();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Audio Language',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: AppConstants.ttsLanguages.map((code) {
                    final isFree = AppConstants.freeTtsLanguages.contains(code);
                    final locked = !isFree && !isPremium;
                    final selected = cubit.state.audioLanguage == code;
                    return ListTile(
                      leading: Text(
                        _audioLanguageName(code).isEmpty ? '🌐' : _flagForCode(code),
                        style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                              fontSize: 22,
                            ),
                      ),
                      title: Text(
                        _audioLanguageName(code),
                        style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                              color: locked ? AppColors.textHint : AppColors.textPrimary,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                      ),
                      trailing: locked
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                                      color: AppColors.textOnAccent,
                                    ),
                              ),
                            )
                          : (selected
                              ? const Icon(Icons.check_circle, color: AppColors.success)
                              : null),
                      onTap: locked
                          ? () {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Upgrade to Premium to unlock this language.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          : () => Navigator.of(sheetContext).pop(code),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked == null || picked == cubit.state.audioLanguage) return;

    // Read the live playing state AFTER the modal closes. The modal could
    // have been open for several seconds; TTS may have completed naturally
    // or the user may have toggled play. Re-checking here keeps the bottom
    // sheet in sync with the actual cubit state.
    final wasPlaying = siteDetailCubit.state.audioState.isPlaying;

    // Update the cubit — chip re-renders immediately.
    await cubit.setAudioLanguage(picked);

    if (!mounted) return;

    // If audio was playing in the old language, stop and restart in the
    // new one. The bottom sheet's play/pause button reads from the cubit
    // so it stays in sync.
    if (wasPlaying) {
      await siteDetailCubit.stopAudio();
      if (!mounted) return;
      await siteDetailCubit.playAudio(picked, isPremium: isPremium);
    }
  }

  String _flagForCode(String code) => LanguageMeta.flag(code);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SiteDetailCubit, SiteDetailState>(
      builder: (context, state) {
        if (state.status == SiteDetailStatus.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        if (state.status == SiteDetailStatus.error || state.site == null) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(state.errorMessage ?? 'Site not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final site = state.site!;
        // Note: uiLanguage, isPremium, and the audio language are read
        // *inside* the relevant callbacks below — the previous build-time
        // capture meant a user upgrading mid-session would still hear the
        // 30s preview until they rebuilt the screen, and a language pick
        // on this screen could race with an older closure.
        final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;
        final locState = context.read<LocalizationCubit>().state;
        // Needed for the upgrade banner and other build-time conditions.
        final isPremium = context.read<AuthCubit>().state.isPremium;
        final allImages = site.allImages;
        final isRtl = Directionality.of(context) == TextDirection.rtl;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: const SizedBox.shrink(),
                expandedHeight: 300,
                pinned: true,
                actions: [
                  BlocBuilder<FavoritesCubit, FavoritesState>(
                    builder: (context, favState) {
                      final isFav = favState.favoriteIds.contains(site.id);
                      final loc = context.watch<LocalizationCubit>().state;
                      final tooltipKey = isFav
                          ? 'remove_from_favorites'
                          : 'add_to_favorites';
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.white,
                        ),
                        tooltip: loc.translations[tooltipKey] ??
                            (isFav ? 'Remove from favorites' : 'Add to favorites'),
                        onPressed: () =>
                            context.read<FavoritesCubit>().toggleFavorite(site.id),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image Carousel
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentImageIndex = index);
                        },
                        itemCount: allImages.length,
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: site.getTransformedImageUrl(
                              transformation: 'w_1200,c_fill,q_auto,f_auto',
                              imageIndex: index,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.surfaceDark,
                              child: const Center(
                                child: CircularProgressIndicator(color: AppColors.accent),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceDark,
                              child: const Icon(Icons.image_not_supported, size: 48),
                            ),
                          );
                        },
                      ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Image indicators (tappable so users can jump between
                      // images even when horizontal swiping is consumed by
                      // the parent CustomScrollView's vertical drag).
                      if (allImages.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              allImages.length,
                              (index) => GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: _currentImageIndex == index ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Image counter
                      if (allImages.length > 1)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 56,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentImageIndex + 1}/${allImages.length}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: context.semanticColors.onImage,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Rating badge
                      if (site.rating != null)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 56,
                          right: 16,
                          child: RatingBadge(rating: site.rating!),
                        ),
                      // Prev / Next arrow buttons — appear when there's more
                      // than one image. Tap-to-cycle works regardless of
                      // whether horizontal swipe is consumed by the parent
                      // CustomScrollView's vertical drag.
                      //
                      // Both icons and geometric positions are mirrored in
                      // RTL so the visual "next" arrow still points forward
                      // in reading order (`Directionality.of(context)` is
                      // set by app.dart for AR, HE, FA, UR). Without this,
                      // Arabic users tapping the visually-left button get
                      // "next" instead of "previous" — a top RTL complaint.
                      if (allImages.length > 1) ...[
                        Positioned(
                          // In LTR, prev sits on the left; in RTL it's
                          // on the right. `isRtl` was captured at the top
                          // of build(); rebuilding on locale change is
                          // handled by the surrounding BlocBuilder.
                          left: isRtl ? null : 8,
                          right: isRtl ? 8 : null,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: isRtl ? Icons.chevron_right : Icons.chevron_left,
                              semanticsLabel: locState.translations['previous_image'] ?? 'Previous image',
                              onTap: _currentImageIndex > 0
                                  ? () => _pageController.previousPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          right: isRtl ? null : 8,
                          left: isRtl ? 8 : null,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: isRtl ? Icons.chevron_left : Icons.chevron_right,
                              semanticsLabel: locState.translations['next_image'] ?? 'Next image',
                              onTap: _currentImageIndex < allImages.length - 1
                                  ? () => _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.getName(uiLanguage),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            site.displayAddress,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Explore this place',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        site.getDescription(uiLanguage),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                      ),
                      const SizedBox(height: 24),
                      // Transcript of what's actually being spoken — sits
                      // between the description and the upgrade banner so
                      // deaf / quiet-environment users can read along.
                      // Collapsed by default; renders only after audio
                      // has been played once (so we have spokenText).
                      Builder(
                        builder: (innerContext) {
                          final audioLang = innerContext
                              .watch<LanguageCubit>()
                              .state
                              .audioLanguage;
                          final audioState = state.audioState;
                          return TranscriptSection(
                            title: 'Transcript',
                            text: audioState.spokenText,
                            audioLanguageCode: audioLang,
                            truncated: audioState.wasTruncated,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!isPremium)
                        UpgradeBanner(
                          onUpgrade: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UpgradeScreen(),
                            ),
                          ),
                          message: '30 sec limit • Upgrade for full audio',
                        ),
                      const SizedBox(height: 16),
                      // Primary action: play audio in-place. The existing
                      // bottomSheet shows the play/pause/progress UI bound
                      // to state.audioState — pressing this button makes
                      // it react immediately.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Read live values inside the callback so an
                            // upgrade or audio-language flip on another
                            // path is picked up by this very tap — the
                            // previous build-time capture meant a user who
                            // upgraded mid-session still got the 30s
                            // preview until they rebuilt the screen.
                            final audioLang =
                                context.read<LanguageCubit>().state.audioLanguage;
                            final liveIsPremium =
                                context.read<AuthCubit>().state.isPremium;
                            context.read<SiteDetailCubit>().playAudio(
                                  audioLang,
                                  isPremium: liveIsPremium,
                                );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Audio Guide'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Secondary actions: open the site on a free OSM map,
                      // or launch live GPS navigation (gated behind a Google
                      // Maps API key — see safePushNavigation).
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SiteMapScreen(site: site),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('View on Map'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => safePushNavigation(context, site),
                              icon: const Icon(Icons.navigation_outlined, size: 18),
                              label: const Text('Navigate'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: Builder(
            builder: (sheetContext) {
              // Read the live audio-language pick inside the sheet so the
              // chip updates as soon as the user picks a new language
              // from the modal.
              final audioLang = sheetContext
                  .watch<LanguageCubit>()
                  .state
                  .audioLanguage;
              // Same logic for premium: a purchase that lands while the
              // sheet is mounted should not require rebuilding the whole
              // Scaffold to apply. The play callback closes over
              // `audioLang`/`isPremium` from this build, but we re-read
              // both inside the closure so the very next tap picks up
              // any freshly-purchased premium state.
              final liveIsPremium = sheetContext.read<AuthCubit>().state.isPremium;
              return AudioPlayerBar(
                audioState: state.audioState,
                audioLanguageCode: audioLang,
                isPremium: liveIsPremium,
                onPlayPause: () {
                  final a = state.audioState;
                  // Re-read inside the callback so a premium purchase
                  // that landed during the current tap is honoured
                  // (the user upgrading mid-session previously kept
                  // hearing the 30s preview until they restarted).
                  final freshLang =
                      sheetContext.read<LanguageCubit>().state.audioLanguage;
                  final freshPremium =
                      sheetContext.read<AuthCubit>().state.isPremium;
                  if (a.isPlaying) {
                    context.read<SiteDetailCubit>().pauseAudio();
                  } else if (a.isPaused) {
                    context.read<SiteDetailCubit>().resumeAudio();
                  } else {
                    context.read<SiteDetailCubit>().playAudio(
                          freshLang,
                          isPremium: freshPremium,
                        );
                  }
                },
                onLanguageTap: () =>
                    _showAudioLanguagePicker(sheetContext, liveIsPremium),
                onReplay: () async {
                  final cubit = context.read<SiteDetailCubit>();
                  // Read live values BEFORE the await so we never use
                  // sheetContext across an async gap (lint rule). The
                  // values are looked up again on the next tap if
                  // anything has changed.
                  final freshLang =
                      sheetContext.read<LanguageCubit>().state.audioLanguage;
                  final freshPremium =
                      sheetContext.read<AuthCubit>().state.isPremium;
                  await cubit.stopAudio();
                  if (!mounted) return;
                  await cubit.playAudio(freshLang, isPremium: freshPremium);
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// Circular semi-transparent arrow button overlaid on the image gallery.
/// When [onTap] is null the button renders disabled. [semanticsLabel] is
/// read aloud by TalkBack / VoiceOver.
class _GalleryArrow extends StatelessWidget {

  const _GalleryArrow({
    required this.icon,
    required this.semanticsLabel,
    this.onTap,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.white54,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

