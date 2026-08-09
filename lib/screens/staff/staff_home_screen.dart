import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class StaffHomeScreen extends StatelessWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final staff = state.staff;

    if (staff == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${staff.role.label} desk'),
        actions: [
          IconButton(
            tooltip: 'Codes and settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(Routes.staffSettings),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().staffSignOut();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.activation,
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<ClientProfile>>(
          stream: state.staffClients(),
          builder: (context, snapshot) {
            final clients = snapshot.data ?? const <ClientProfile>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (clients.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No activated clients yet. Create an activation code from settings '
                    'after a client pays through Docketwise.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: clients.length,
              itemBuilder: (context, index) =>
                  _ClientRow(client: clients[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client});

  final ClientProfile client;

  Color _statusColor(LobbyStatus status) => switch (status) {
        LobbyStatus.waiting => AppColors.waiting,
        LobbyStatus.ready => AppColors.ready,
        LobbyStatus.withAttorney => AppColors.attorney,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<LobbyState>(
          stream: state.lobbyFor(client.id),
          builder: (context, snapshot) {
            final lobby = snapshot.data ?? LobbyState.empty(client.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusPill(
                      label: lobby.status.label,
                      color: _statusColor(lobby.status),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(client.email,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Action(
                      label: 'Ready',
                      onTap: () => state.setLobbyStatus(
                          client.id, LobbyStatus.ready),
                    ),
                    _Action(
                      label: 'Transfer to attorney',
                      onTap: () => state.setLobbyStatus(
                          client.id, LobbyStatus.withAttorney),
                    ),
                    _Action(
                      label: 'Complete',
                      onTap: () => state.setLobbyStatus(
                          client.id, LobbyStatus.completed),
                    ),
                    _Action(
                      label: 'Open chat',
                      onTap: () => Navigator.of(context).pushNamed(
                        Routes.staffClient,
                        arguments: client,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
