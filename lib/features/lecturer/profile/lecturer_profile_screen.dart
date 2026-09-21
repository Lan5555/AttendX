import 'package:attendx/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/models/lecturer.dart';
import '../../../shared/mock/mock_data.dart';

class LecturerProfileScreen extends StatelessWidget {
  const LecturerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AuthController>();
    final lecturer = appState.currentUser is Lecturer ? appState.currentUser as Lecturer : MockData.demoLecturer;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    lecturer.fullName.trim().isNotEmpty ? lecturer.fullName.trim()[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('${lecturer.title} ${lecturer.fullName}', style: Theme.of(context).textTheme.titleLarge),
                Text(lecturer.staffId, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                _InfoTile(icon: Icons.email_outlined, label: 'Email', value: lecturer.email),
                const Divider(height: 1),
                _InfoTile(icon: Icons.account_balance_outlined, label: 'Department', value: lecturer.department),
                const Divider(height: 1),
                _InfoTile(icon: Icons.apartment_rounded, label: 'Faculty', value: lecturer.faculty),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActionTile(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => _showComingSoon(context)),
          _ActionTile(icon: Icons.lock_reset_rounded, label: 'Change Password', onTap: () => _showComingSoon(context)),
          _ActionTile(icon: Icons.notifications_outlined, label: 'Notification Settings', onTap: () => _showComingSoon(context)),
          _ActionTile(icon: Icons.info_outline_rounded, label: 'About AttendX', onTap: () => _showAbout(context)),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(icon: Icons.logout_rounded, label: 'Logout', isDestructive: true, onTap: () => _confirmLogout(context)),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This will be available once the backend is connected.')),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AttendX',
      applicationVersion: '1.0.0 (MVP)',
      applicationLegalese: 'Secure Attendance. Smarter Campus.',
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.read<AuthController>().logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textTertiary, size: 20),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.textSecondary),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}
