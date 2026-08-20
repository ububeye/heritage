import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../../blocs/site_list/site_list_state.dart';
import '../../../blocs/localization/localization_cubit.dart';
import '../../../data/models/site_model.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../widgets/search_bar_widget.dart';
import 'admin_add_site_screen.dart';
import 'admin_edit_site_screen.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AdminSitesScreen extends StatefulWidget {
  const AdminSitesScreen({super.key, this.addNew = false});
  final bool addNew;

  @override
  State<AdminSitesScreen> createState() => _AdminSitesScreenState();
}

class _AdminSitesScreenState extends State<AdminSitesScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<SiteListCubit>().loadSites();
    if (widget.addNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminAddSiteScreen()));
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SiteModel> _filterSites(List<SiteModel> sites) {
    if (_searchQuery.isEmpty) return sites;
    return sites.where((site) {
      final name = site.nameEn.toLowerCase();
      final category = site.category?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: BlocBuilder<LocalizationCubit, LocalizationState>(
          builder: (context, loc) {
            return Text(loc.translations['admin_tab_sites'] ?? 'Sites');
          },
        ),
      ),
      body: BlocBuilder<LocalizationCubit, LocalizationState>(
        builder: (context, loc) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: SearchBarWidget(
                  controller: _searchController,
                  hintText: loc.translations['search_sites'] ?? 'Search sites…',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              Expanded(
                child: BlocBuilder<SiteListCubit, SiteListState>(
                  builder: (context, state) {
                    if (state.status == SiteListStatus.loading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      );
                    }

                    final sites = _filterSites(state.sites);

                    if (sites.isEmpty) {
                      return _EmptyState(
                        query: _searchQuery,
                        loc: loc,
                        onAdd:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminAddSiteScreen(),
                              ),
                            ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh:
                          () => context.read<SiteListCubit>().loadSites(),
                      color: Theme.of(context).colorScheme.secondary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: sites.length,
                        itemBuilder: (context, index) {
                          final site = sites[index];
                          return _SiteCard(
                            site: site,
                            loc: loc,
                            onEdit:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => AdminEditSiteScreen(site: site),
                                  ),
                                ),
                            onDelete: () async {
                              final confirmed = await _confirmDelete(
                                context,
                                site,
                                loc,
                              );
                              if (confirmed == true) {
                                await _deleteSite(site, loc);
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminAddSiteScreen()),
            ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(PhosphorIconsRegular.plus),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    SiteModel site,
    LocalizationState loc,
  ) {
    final bodyTemplate =
        loc.translations['delete_site_confirm_body'] ??
        'Are you sure you want to delete "%s"?';
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              loc.translations['delete_site_confirm_title'] ?? 'Delete Site',
            ),
            content: Text(bodyTemplate.replaceAll('%s', site.nameEn)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(loc.translations['cancel'] ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(loc.translations['delete'] ?? 'Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteSite(SiteModel site, LocalizationState loc) async {
    try {
      await _firestoreService.deleteSite(site.id);
      await _firestoreService.logActivity(
        ActivityModel(
          id: '', // Firestore auto-generates
          type: 'site_updated',
          title: 'Site deleted',
          subtitle: 'Admin deleted "${site.nameEn}".',
          timestamp: DateTime.now(),
        ),
      );
      if (mounted) {
        context.read<SiteListCubit>().loadSites();
        final messenger = ScaffoldMessenger.maybeOf(context);
        final template = loc.translations['site_deleted'] ?? '%s deleted';
        messenger?.showSnackBar(
          SnackBar(
            content: Text(template.replaceAll('%s', site.nameEn)),
            backgroundColor: context.semanticColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.query,
    required this.loc,
    required this.onAdd,
  });
  final String query;
  final LocalizationState loc;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searching ? PhosphorIconsRegular.magnifyingGlassMinus : Icons.location_city,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? (loc.translations['no_results'] ?? 'No results')
                : (loc.translations['no_favorites'] ?? 'No sites yet'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (!searching) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(PhosphorIconsRegular.plus),
              label: Text(loc.translations['no_sites_cta'] ?? 'Add First Site'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.loc,
    required this.onEdit,
    required this.onDelete,
  });
  final SiteModel site;
  final LocalizationState loc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final featuredLabel =
        site.featured
            ? (loc.translations['remove_featured'] ?? 'Remove from featured')
            : (loc.translations['set_featured'] ?? 'Set as featured');
    final editLabel = loc.translations['edit_site_a11y'] ?? 'Edit site';
    final deleteLabel = loc.translations['delete_site_a11y'] ?? 'Delete site';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      child: InkWell(
        onTap: onEdit,
        borderRadius: AppRadius.mdBorder,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.bannerBorder,
                child: CachedNetworkImage(
                  imageUrl: site.primaryImage,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        width: 64,
                        height: 64,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.secondary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        width: 64,
                        height: 64,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            site.nameEn,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (site.featured) ...[
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIconsFill.star,
                            size: 16,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: AppInsets.pillTiny,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.xsBorder,
                      ),
                      child: Text(
                        site.category ?? 'Uncategorized',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.mapPin,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${site.latitude.toStringAsFixed(4)}, ${site.longitude.toStringAsFixed(4)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Single row of three icon buttons. Replaces the previous
              // star / [edit, delete] stacked Column — easier to scan,
              // no thumb-trap, no Dismissible swipe conflict.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      site.featured ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                      color:
                          site.featured
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outline,
                    ),
                    tooltip: featuredLabel,
                    onPressed:
                        () => context.read<SiteListCubit>().setFeatured(
                          site.id,
                          !site.featured,
                        ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      PhosphorIconsRegular.pencilSimple,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: editLabel,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      PhosphorIconsRegular.trash,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: deleteLabel,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
