import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';

class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.staffSession?.user;

    return ScreenScaffold(
      title: 'Profile',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Staff',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 10),
                StatusPill(
                  label: user?.role.label ?? 'Staff',
                  color: AppColors.navy,
                ),
                const SizedBox(height: 12),
                Text(
                  'Capabilities: ${(user?.capabilities ?? []).join(', ')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Sign out',
            onPressed: () async {
              await app.staffLogout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}