import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../models/client_models.dart';
import '../../services/app_backend.dart';
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: Text('${staff.role.label} desk'),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFFD7E0EA),
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(
              Colors.white.withValues(alpha: 0.08),
            ),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [
              const Tab(text: 'Live queue'),
              const Tab(text: 'Appointments'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('App clients'),
                    if (state.totalClientUnread > 0) ...[
                      const SizedBox(width: 6),
                      UnreadBadge(count: state.totalClientUnread, compact: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
        body: Stack(
          children: [
            TabBarView(
              children: [
                _LiveQueueTab(state: state),
                _AppointmentsTab(state: state),
                _AppClientsTab(state: state),
              ],
            ),
            _StaffUnreadListener(state: state),
          ],
        ),
      ),
    );
  }
}

class _LiveQueueTab extends StatelessWidget {
  const _LiveQueueTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ScrollScreenBody(
      child: StreamBuilder<LobbyQueueSnapshot>(
        stream: state.staffQueue(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final queue = snapshot.data ?? LobbyQueueSnapshot.empty();

          if (!state.usesLiveBackend) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Live queue syncs with the website when the app uses WordPress.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          if (queue.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!queue.lobbyOpen) ...[
                      const StatusPill(
                        label: 'Lobby closed',
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      queue.lobbyOpen
                          ? 'No one is waiting in the Virtual Lobby right now.'
                          : 'The Virtual Lobby is closed on the website.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!queue.lobbyOpen)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StatusPill(
                    label: 'Lobby closed on website',
                    color: AppColors.danger,
                  ),
                ),
              ...queue.items.map(
                (visit) => _QueueVisitRow(
                  visit: visit,
                  state: state,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueVisitRow extends StatelessWidget {
  const _QueueVisitRow({
    required this.visit,
    required this.state,
  });

  final QueueVisit visit;
  final AppState state;

  Color _statusColor(QueueVisitStatus status) => switch (status) {
        QueueVisitStatus.waiting => AppColors.waiting,
        QueueVisitStatus.ready => AppColors.ready,
        QueueVisitStatus.inMeeting => AppColors.inMeeting,
        QueueVisitStatus.withAttorney => AppColors.attorney,
      };

  Future<void> _runAction(
    BuildContext context,
    String action,
  ) async {
    try {
      await context.read<AppState>().setQueueAction(visit, action);
    } on BackendException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final clientId = visit.appClientId;
    if (clientId == null) return;

    final profile = await context.read<AppState>().backend.loadClient(clientId);
    if (!context.mounted || profile == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open app client chat.')),
        );
      }
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.staffClient,
      arguments: profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusPill(
                  label: visit.statusLabel,
                  color: _statusColor(visit.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              visit.isAppClient ? 'Mobile app client' : 'Website visitor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (visit.matter.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Matter: ${visit.matter}'),
            ],
            if (visit.phone.isNotEmpty && visit.phone != '—') ...[
              const SizedBox(height: 4),
              Text('Phone: ${visit.phone}'),
            ],
            if (visit.status == QueueVisitStatus.waiting) ...[
              const SizedBox(height: 4),
              Text(
                'Position ${visit.positionLabel}'
                '${visit.waitLabel.isNotEmpty ? ' · ${visit.waitLabel}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (visit.status == QueueVisitStatus.waiting)
                  _ActionChip(
                    label: 'Ready',
                    onTap: () => _runAction(context, 'ready'),
                  ),
                if (visit.status == QueueVisitStatus.ready ||
                    visit.status == QueueVisitStatus.inMeeting)
                  _ActionChip(
                    label: 'Transfer to attorney',
                    onTap: () => _runAction(context, 'transfer'),
                  ),
                if (visit.status != QueueVisitStatus.waiting)
                  _ActionChip(
                    label: 'Complete',
                    onTap: () => _runAction(context, 'complete'),
                  ),
                if (visit.status == QueueVisitStatus.waiting)
                  _ActionChip(
                    label: 'Dismiss',
                    onTap: () => _runAction(context, 'dismiss'),
                  ),
                if (visit.isAppClient)
                  _ActionChip(
                    label: 'Open chat',
                    unread: visit.appClientId == null
                        ? 0
                        : state.unreadCountFor(visit.appClientId!),
                    onTap: () => _openChat(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ScrollScreenBody(
      child: StreamBuilder<List<AppointmentRequest>>(
        stream: state.staffAppointments(),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <AppointmentRequest>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No appointment requests yet. They appear here when a client '
                  'uses the app or completes the website Virtual Lobby wizard.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _AppointmentRow(request: requests[index]),
          );
        },
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.request});

  final AppointmentRequest request;

  Future<void> _setStatus(
    BuildContext context,
    AppointmentStatus status,
  ) async {
    try {
      await context.read<AppState>().setAppointmentStatus(request.id, status);
    } on BackendException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.clientName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                StatusPill(
                  label: request.sourceLabel,
                  color: request.isWebsite ? AppColors.waiting : AppColors.navy,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.preferredWindow,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (request.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Phone: ${request.phone}'),
            ],
            if (request.email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Email: ${request.email}'),
            ],
            if (request.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(request.note),
            ],
            const SizedBox(height: 6),
            Text(
              DateFormat('MMM d, h:mm a').format(request.createdAt),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatusPill(
                  label: request.status.label,
                  color: switch (request.status) {
                    AppointmentStatus.confirmed => AppColors.success,
                    AppointmentStatus.declined => AppColors.danger,
                    AppointmentStatus.requested => AppColors.waiting,
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      _setStatus(context, AppointmentStatus.confirmed),
                  child: const Text('Confirm'),
                ),
                TextButton(
                  onPressed: () =>
                      _setStatus(context, AppointmentStatus.declined),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppClientsTab extends StatelessWidget {
  const _AppClientsTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ScrollScreenBody(
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

  Future<void> _runLobbyAction(
    BuildContext context,
    LobbyStatus status,
  ) async {
    try {
      await context.read<AppState>().setLobbyStatus(client.id, status);
    } on BackendException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unread = state.unreadCountFor(client.threadId);

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
                    UnreadBadge(count: unread),
                    if (unread > 0) const SizedBox(width: 8),
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
                    _ActionChip(
                      label: 'Ready',
                      onTap: () => _runLobbyAction(context, LobbyStatus.ready),
                    ),
                    _ActionChip(
                      label: 'Transfer to attorney',
                      onTap: () =>
                          _runLobbyAction(context, LobbyStatus.withAttorney),
                    ),
                    _ActionChip(
                      label: 'Complete',
                      onTap: () =>
                          _runLobbyAction(context, LobbyStatus.completed),
                    ),
                    _ActionChip(
                      label: 'Open chat',
                      unread: unread,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.unread = 0,
  });

  final String label;
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unread > 0) ...[
            const SizedBox(width: 6),
            UnreadBadge(count: unread, compact: true),
          ],
        ],
      ),
      onPressed: onTap,
      labelStyle: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Keeps unread counts live on the desk without opening each chat.
class _StaffUnreadListener extends StatefulWidget {
  const _StaffUnreadListener({required this.state});

  final AppState state;

  @override
  State<_StaffUnreadListener> createState() => _StaffUnreadListenerState();
}

class _StaffUnreadListenerState extends State<_StaffUnreadListener> {
  StreamSubscription<List<ClientProfile>>? _clientsSub;
  final Map<String, StreamSubscription<List<ChatMessage>>> _threadSubs = {};

  @override
  void initState() {
    super.initState();
    _clientsSub = widget.state.staffClients().listen(_syncClients);
  }

  @override
  void dispose() {
    _clientsSub?.cancel();
    for (final sub in _threadSubs.values) {
      sub.cancel();
    }
    _threadSubs.clear();
    super.dispose();
  }

  void _syncClients(List<ClientProfile> clients) {
    final active = {for (final client in clients) client.threadId: client};
    for (final threadId in _threadSubs.keys.toList()) {
      if (active.containsKey(threadId)) continue;
      _threadSubs.remove(threadId)?.cancel();
      widget.state.clearUnread(threadId);
    }
    for (final client in clients) {
      if (_threadSubs.containsKey(client.threadId)) continue;
      _threadSubs[client.threadId] =
          widget.state.threadFor(client.threadId).listen((messages) {
        widget.state.updateUnreadForThread(client.threadId, messages);
      });
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
