import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_constants.dart';
import '../../blocs/site_detail/site_detail_cubit.dart';
import '../../blocs/site_detail/site_detail_state.dart';
import '../../blocs/language/language_cubit.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../widgets/audio_player_card.dart';
import '../widgets/upgrade_banner.dart';
import '../widgets/rating_stars.dart';
import 'navigation_screen.dart';

class DetailScreen extends StatefulWidget {
  final String siteId;

  const DetailScreen({super.key, required this.siteId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SiteDetailCubit>().loadSite(widget.siteId);
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
            appBar: AppBar(),
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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: site.getTransformedImageUrl(
                          transformation: 'w_1200,c_fill,q_auto,f_auto',
                        ),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceDark,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surfaceDark,
                          child: const Icon(Icons.image_not_supported, size: 48),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                      if (site.rating != null)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 56,
                          right: 16,
                          child: RatingBadge(rating: site.rating!),
                        ),
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
                            'Stone Town, Zanzibar',
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
                          onUpgrade: () {
                            // Navigate to upgrade screen
                          },
                          message: '30 sec limit • Upgrade for full audio',
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NavigationScreen(site: site),
                              ),
                            );
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text('Start Audio Guide'),
                        ),
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
                  color: Colors.black.withOpacity(0.1),
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
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.replay, color: AppColors.primary),
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