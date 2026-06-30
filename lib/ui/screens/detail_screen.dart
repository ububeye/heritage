import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../blocs/site_detail/site_detail_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/favorites/favorites_cubit.dart';
import '../../core/utils/nav_guard.dart';
import '../widgets/upgrade_banner.dart';
import '../widgets/rating_stars.dart';
import 'site_map_screen.dart';
import 'upgrade_screen.dart';
import '../../blocs/localization/localization_cubit.dart';

class DetailScreen extends StatefulWidget {
  final String siteId;

  const DetailScreen({super.key, required this.siteId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    context.read<SiteDetailCubit>().loadSite(widget.siteId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Display name for the audio-language chip.
  String _audioLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'sw':
        return 'Kiswahili';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ar':
        return 'العربية';
      case 'it':
        return 'Italiano';
      case 'es':
        return 'Español';
      default:
        return code;
    }
  }

  /// Show a modal bottom sheet with the 7 audio languages. Free users see
  /// the 5 premium languages greyed out with a "Premium" badge; tapping a
  /// free language updates the cubit and (if audio is currently playing)
  /// restarts playback in the new language.
  Future<void> _showAudioLanguagePicker(BuildContext context, bool isPremium) async {
    final cubit = context.read<LanguageCubit>();
    final siteDetailCubit = context.read<SiteDetailCubit>();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Audio Language',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        _audioLanguageName(code),
                        style: TextStyle(
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
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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

  String _flagForCode(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'sw':
        return '🇹🇿';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'ar':
        return '🇸🇦';
      case 'it':
        return '🇮🇹';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }

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
        final uiLanguage = context.read<LanguageCubit>().state.uiLanguage;
        final isPremium = context.read<AuthCubit>().state.isPremium;
        final allImages = site.allImages;

        return Scaffold(
          backgroundColor: AppColors.background,
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
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
                      if (allImages.length > 1) ...[
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: Icons.chevron_left,
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
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _GalleryArrow(
                              icon: Icons.chevron_right,
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            site.displayAddress,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Explore this place',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        site.getDescription(uiLanguage),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            final audioLang = context.read<LanguageCubit>().state.audioLanguage;
                            final isPremium = context.read<AuthCubit>().state.isPremium;
                            context.read<SiteDetailCubit>().playAudio(
                                  audioLang,
                                  isPremium: isPremium,
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
          bottomSheet: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
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
                  GestureDetector(
                    onTap: () {
                      final audioState = state.audioState;
                      if (audioState.isPlaying) {
                        context.read<SiteDetailCubit>().pauseAudio();
                      } else {
                        final audioLang = context.read<LanguageCubit>().state.audioLanguage;
                        context.read<SiteDetailCubit>().playAudio(audioLang, isPremium: isPremium);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        state.audioState.isPlaying ? Icons.pause : Icons.play_arrow,
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
                        // Language chip — tap to switch audio language
                        // in-place. Stops current audio (if playing) and
                        // starts in the new language when one is picked.
                        Builder(
                          builder: (innerContext) {
                            final audioLang = innerContext.watch<LanguageCubit>().state.audioLanguage;
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: _AudioLanguageChip(
                                code: audioLang,
                                name: _audioLanguageName(audioLang),
                                onTap: () => _showAudioLanguagePicker(innerContext, isPremium),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: state.audioState.progress.clamp(0.0, 1.0),
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          minHeight: 4,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${state.audioState.positionText} / ${state.audioState.durationText}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPremium)
                    Builder(
                      builder: (innerContext) => IconButton(
                        tooltip: 'Replay',
                        onPressed: () async {
                          final audioLang = innerContext.read<LanguageCubit>().state.audioLanguage;
                          final cubit = innerContext.read<SiteDetailCubit>();
                          await cubit.stopAudio();
                          if (!mounted) return;
                          await cubit.playAudio(audioLang, isPremium: isPremium);
                        },
                        icon: const Icon(Icons.replay, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular semi-transparent arrow button overlaid on the image gallery.
/// When [onTap] is null the button renders disabled.
class _GalleryArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GalleryArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
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
    );
  }
}

/// Language flag emoji + display name + a small chevron.
/// Tapping invokes [onTap]. Used as the audio-language chip on the
/// bottom-sheet player.
class _AudioLanguageChip extends StatelessWidget {
  final String code;
  final String name;
  final VoidCallback onTap;

  const _AudioLanguageChip({
    required this.code,
    required this.name,
    required this.onTap,
  });

  String get _flag {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'sw':
        return '🇹🇿';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'ar':
        return '🇸🇦';
      case 'it':
        return '🇮🇹';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}