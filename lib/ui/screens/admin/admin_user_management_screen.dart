import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class AdminUserManagementScreen extends StatelessWidget {
  const AdminUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'User Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage users and premium subscriptions',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'This feature requires Firebase Admin SDK setup.\nUser management will be available soon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}