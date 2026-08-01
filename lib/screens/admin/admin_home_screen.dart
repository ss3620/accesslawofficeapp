import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.staffSession?.user;

    return ScreenScaffold(
      title: 'Admin',
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => Navigator.of(context).pushNamed('/staff/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome, ${user?.displayName ?? 'Admin'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure Zoom, manage receptionists, and oversee the lobby.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          _AdminTile(
            icon: Icons.queue_outlined,
            title: 'Live queue',
            subtitle: 'Ready, transfer, complete, dismiss',
            onTap: () => Navigator.of(context).pushNamed('/receptionist/queue'),
          ),
          _AdminTile(
            icon: Icons.videocam_outlined,
            title: 'Zoom & lobby settings',
            subtitle: 'Reception / attorney rooms & feature flags',
            onTap: () => Navigator.of(context).pushNamed('/admin/settings'),
          ),
          _AdminTile(
            icon: Icons.badge_outlined,
            title: 'Staff users',
            subtitle: 'Create or deactivate receptionists',
            onTap: () => Navigator.of(context).pushNamed('/admin/staff'),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.navy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}