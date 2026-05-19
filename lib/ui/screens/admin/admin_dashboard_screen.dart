import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/colors.dart';
import '../../../blocs/site_list/site_list_cubit.dart';
import '../../../blocs/site_list/site_list_state.dart';
import '../../../blocs/auth/auth_cubit.dart';
import '../../../data/models/site_model.dart';
import 'admin_add_site_screen.dart';
import 'admin_edit_site_screen.dart';
import 'admin_user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SiteListCubit>().loadSites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()),
            ),
          ),
        ],
      ),
      body: BlocBuilder<SiteListCubit, SiteListState>(
        builder: (context, state) {
          if (state.status == SiteListStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          final sites = state.sites;

          if (sites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_city,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No sites yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminAddSiteScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Site'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sites.length,
            itemBuilder: (context, index) {
              final site = sites[index];
              return _SiteListItem(
                site: site,
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminEditSiteScreen(site: site),
                  ),
                ),
                onDelete: () => _showDeleteDialog(context, site),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminAddSiteScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, SiteModel site) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Site'),
        content: Text('Are you sure you want to delete "${site.nameEn}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete site
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SiteListItem extends StatelessWidget {
  final SiteModel site;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SiteListItem({
    required this.site,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            site.cloudinaryImageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 60,
              height: 60,
              color: AppColors.surfaceDark,
              child: const Icon(Icons.image, color: AppColors.textHint),
            ),
          ),
        ),
        title: Text(
          site.nameEn,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          site.category ?? 'Uncategorized',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}