import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class LobbyHomeScreen extends StatefulWidget {
  const LobbyHomeScreen({super.key});

  @override
  State<LobbyHomeScreen> createState() => _LobbyHomeScreenState();
}

class _LobbyHomeScreenState extends State<LobbyHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.refreshConfig();
      if (app.activeVisit != null) {
        Navigator.of(context).pushReplacementNamed('/client/waiting');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final config = app.config;
    final isOpen = config?.isOpen ?? false;

    return ScreenScaffold(
      title: 'Virtual Lobby',
      actions: [
        IconButton(
          tooltip: 'Exit',
          onPressed: () async {
            await app.clientLogout();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            }
          },
          icon: const Icon(Icons.close),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const BrandHeader(compact: true),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: isOpen ? 'Lobby open' : 'Lobby closed',
                      color: isOpen ? AppColors.success : AppColors.danger,
                    ),
                    const Spacer(),
                    if (config != null)
                      Text(
                        '${config.waitingCount} waiting',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Office hours (CST)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  config?.hoursCopy ?? 'Loading…',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Meet with our receptionist and attorney online. Meetings are 100% virtual — no in-person appointments.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: isOpen ? 'Enter Lobby' : 'Lobby is closed',
            onPressed: isOpen
                ? () => Navigator.of(context).pushNamed('/client/name')
                : null,
          ),
          if (!isOpen) ...[
            const SizedBox(height: 12),
            Text(
              'Please check back during office hours, or call the office if you need urgent help.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}