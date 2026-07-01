import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/colors.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../../blocs/site_list/site_list_state.dart';
import '../../../blocs/user/user_cubit.dart';
import '../../../data/models/site_model.dart';

/// Real analytics dashboard for admins. All numbers are derived client-side
/// from the in-memory [SiteListCubit] and [UserCubit] state — no extra Firestore
/// reads are needed beyond the existing watch streams.
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    String tr(String key, String fallback) => loc.translations[key] ?? fallback;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr('analytics', 'Analytics')),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          // Capture cubits before awaits so we don't hold a BuildContext
          // across the async gap (and so we don't re-read it on every
          // refresh while a rebuild is in flight).
          final siteCubit = context.read<SiteListCubit>();
          final userCubit = context.read<UserCubit>();
          await siteCubit.loadSites();
          await userCubit.loadUsers();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('analytics_subtitle', 'Site & user statistics'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _StatsRow(loc: loc),
              const SizedBox(height: 24),
              _SectionHeader(title: tr('analytics_by_category', 'Sites by Category')),
              const SizedBox(height: 12),
              BlocBuilder<SiteListCubit, SiteListState>(
                builder: (context, state) =>
                    _CategoryBreakdown(sites: state.sites, loc: loc),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: tr('analytics_top_rated', 'Top Rated Sites')),
              const SizedBox(height: 12),
              BlocBuilder<SiteListCubit, SiteListState>(
                builder: (context, state) =>
                    _TopRatedList(sites: state.sites, loc: loc),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.loc});
  final LocalizationState loc;

  @override
  Widget build(BuildContext context) {
    String tr(String key, String fallback) => loc.translations[key] ?? fallback;

    return Row(
      children: [
        Expanded(
          child: BlocBuilder<SiteListCubit, SiteListState>(
            builder: (context, state) => _StatTile(
              icon: Icons.location_city,
              value: state.sites.length.toString(),
              label: tr('analytics_total_sites', 'Total Sites'),
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) => _StatTile(
              icon: Icons.people,
              value: state.totalUsers.toString(),
              label: tr('analytics_total_users', 'Total Users'),
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BlocBuilder<UserCubit, UserState>(
            builder: (context, state) => _StatTile(
              icon: Icons.workspace_premium,
              value: state.premiumUsers.toString(),
              label: tr('analytics_premium_users', 'Premium Users'),
              color: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {

  const _CategoryBreakdown({required this.sites, required this.loc});
  final List<SiteModel> sites;
  final LocalizationState loc;

  @override
  Widget build(BuildContext context) {
    if (sites.isEmpty) {
      return _EmptyBlock(text: loc.translations['search_places'] ?? 'No data yet');
    }

    // Group by category and count. "Uncategorized" is its own bucket so a
    // site without a category tag still appears in the chart.
    final counts = <String, int>{};
    for (final site in sites) {
      final key = site.category ?? 'uncategorized';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _CategoryBar(
                label: entry.key == 'uncategorized'
                    ? 'Uncategorized'
                    : (SiteCategories.labels[entry.key] ?? entry.key),
                count: entry.value,
                maxValue: maxValue,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {

  const _CategoryBar({
    required this.label,
    required this.count,
    required this.maxValue,
  });
  final String label;
  final int count;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue == 0 ? 0.0 : count / maxValue;
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: AppColors.surfaceDark,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopRatedList extends StatelessWidget {

  const _TopRatedList({required this.sites, required this.loc});
  final List<SiteModel> sites;
  final LocalizationState loc;

  @override
  Widget build(BuildContext context) {
    final rated = sites
        .where((s) => s.rating != null)
        .toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));
    final top = rated.take(5).toList();

    if (top.isEmpty) {
      return _EmptyBlock(
        text: loc.translations['analytics_no_rating'] ?? 'No ratings yet',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                top[i].nameEn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(top[i].category ?? '—'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: AppColors.rating),
                  const SizedBox(width: 4),
                  Text(
                    top[i].rating!.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.bar_chart, size: 36, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
