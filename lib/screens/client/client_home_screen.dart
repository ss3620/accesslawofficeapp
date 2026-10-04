import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_settings_card.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  Future<void> _confirmEmergency(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alert your legal team?'),
        content: const Text(
          'This sends an urgent message to your attorney and receptionist right now. '
          'Use it only if you believe you are about to be detained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Send alert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppState>().sendEmergencyAlert();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your legal team has been alerted.')),
    );
    Navigator.of(context).pushNamed(Routes.chat);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final client = state.client;

    if (client == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Access Law Firm'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AppState>().signOutClient();
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
          ScrollScreenBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hello, ${client.name.split(' ').first}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Your attorney and receptionist share one thread with you. '
                'No case updates are ever sent in a notification.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _LobbyBanner(clientId: client.id),
              const SizedBox(height: 16),
              const NotificationSettingsCard(),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.forum_outlined,
                title: 'Message my legal team',
                subtitle: 'Attorney and reception in one chat',
                onTap: () => Navigator.of(context).pushNamed(Routes.chat),
              ),
              _ActionTile(
                icon: Icons.videocam_outlined,
                title: 'Video lobby',
                subtitle: 'Check in now and wait to be seen',
                onTap: () => Navigator.of(context).pushNamed(Routes.videoLobby),
              ),
              _ActionTile(
                icon: Icons.event_available_outlined,
                title: 'Request an appointment',
                subtitle: '30-minute times from 9:00 AM to 4:00 PM',
                onTap: () => Navigator.of(context).pushNamed(Routes.appointment),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => _confirmEmergency(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                ),
                icon: const Icon(Icons.priority_high),
                label: const Text('I am about to be detained'),
              ),
              const SizedBox(height: 12),
              Text(
                'Documents and invoices stay in Docketwise — check your email for those.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
          ),
          _ClientAlertListener(),
        ],
      ),
    );
  }
}

class _ClientAlertListener extends StatefulWidget {
  @override
  State<_ClientAlertListener> createState() => _ClientAlertListenerState();
}

class _ClientAlertListenerState extends State<_ClientAlertListener> {
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  StreamSubscription<List<AppointmentRequest>>? _appointmentsSub;
  String? _lastStaffMessageId;
  bool _messagesPrimed = false;
  final Map<String, AppointmentStatus> _appointmentStatus = {};
  bool _appointmentsPrimed = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _messagesSub = state.clientMessages().listen(_onMessages);
    _appointmentsSub = state.clientAppointments().listen(_onAppointments);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _appointmentsSub?.cancel();
    super.dispose();
  }

  void _onMessages(List<ChatMessage> messages) {
    ChatMessage? latestStaff;
    for (final message in messages.reversed) {
      if (message.senderRole == SenderRole.client) continue;
      if (message.senderRole == SenderRole.system) continue;
      latestStaff = message;
      break;
    }
    final latestId = latestStaff?.id;
    if (!_messagesPrimed) {
      _messagesPrimed = true;
      _lastStaffMessageId = latestId;
      return;
    }
    if (latestId == null || latestId == _lastStaffMessageId) return;
    _lastStaffMessageId = latestId;
    context.read<AppState>().notifyStaffReply();
  }

  void _onAppointments(List<AppointmentRequest> requests) {
    if (!_appointmentsPrimed) {
      for (final request in requests) {
        _appointmentStatus[request.id] = request.status;
      }
      _appointmentsPrimed = true;
      return;
    }
    final state = context.read<AppState>();
    for (final request in requests) {
      final previous = _appointmentStatus[request.id];
      if (previous != null &&
          previous != request.status &&
          (request.status == AppointmentStatus.confirmed ||
              request.status == AppointmentStatus.declined)) {
        state.notifyAppointmentUpdate(
          window: request.preferredWindow,
          status: request.status.label.toLowerCase(),
        );
      }
      _appointmentStatus[request.id] = request.status;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LobbyBanner extends StatelessWidget {
  const _LobbyBanner({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return StreamBuilder<LobbyState>(
      stream: state.lobbyFor(clientId),
      builder: (context, snapshot) {
        final lobby = snapshot.data;
        if (lobby == null || lobby.status == LobbyStatus.idle) {
          return const SizedBox.shrink();
        }
        final ready = lobby.canJoinReception || lobby.canJoinAttorney;
        return SectionCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(
                      label: lobby.status.label,
                      color: ready ? AppColors.ready : AppColors.waiting,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ready
                          ? 'Your call is ready to join.'
                          : 'You are checked in. We will notify you.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.videoLobby),
                child: const Text('Open'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
                  width: 46,
                  height: 46,
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
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodyMedium),
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
