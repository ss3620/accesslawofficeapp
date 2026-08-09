import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

/// Client side of the receptionist -> attorney handoff. Status is driven by
/// staff; the client just sees whose room to join.
class VideoLobbyScreen extends StatelessWidget {
  const VideoLobbyScreen({super.key});

  Future<void> _join(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The meeting link is not set up yet.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
  }

  Color _statusColor(LobbyStatus status) => switch (status) {
        LobbyStatus.waiting => AppColors.waiting,
        LobbyStatus.ready => AppColors.ready,
        LobbyStatus.withAttorney => AppColors.attorney,
        LobbyStatus.completed => AppColors.muted,
        LobbyStatus.idle => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Video lobby')),
      body: SafeArea(
        child: StreamBuilder<LobbyState>(
          stream: state.clientLobby(),
          builder: (context, snapshot) {
            final lobby = snapshot.data;
            if (lobby == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(
                        label: lobby.status.label,
                        color: _statusColor(lobby.status),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        switch (lobby.status) {
                          LobbyStatus.idle =>
                            'Check in when you are ready to be seen.',
                          LobbyStatus.waiting =>
                            'You are in line. Keep the app open — we will let you know the moment reception is free.',
                          LobbyStatus.ready =>
                            'Reception is ready for you now.',
                          LobbyStatus.withAttorney =>
                            'You have been transferred. Leave the reception call first, then join your attorney.',
                          LobbyStatus.completed =>
                            'This session is finished. Message us any time.',
                        },
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (lobby.status == LobbyStatus.idle)
                  PrimaryButton(
                    label: 'Check in to the lobby',
                    onPressed: () => context.read<AppState>().enterLobby(),
                  ),
                if (lobby.status == LobbyStatus.waiting) ...[
                  const _WaitingGuidance(),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.read<AppState>().leaveLobby(),
                    child: const Text('Leave the lobby'),
                  ),
                ],
                if (lobby.canJoinReception)
                  PrimaryButton(
                    label: 'Join reception call',
                    gold: true,
                    onPressed: () => _join(context, lobby.receptionZoomUrl),
                  ),
                if (lobby.canJoinAttorney)
                  PrimaryButton(
                    label: 'Join attorney call',
                    gold: true,
                    onPressed: () => _join(context, lobby.attorneyZoomUrl),
                  ),
                if (lobby.status == LobbyStatus.completed)
                  PrimaryButton(
                    label: 'Back to home',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WaitingGuidance extends StatelessWidget {
  const _WaitingGuidance();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text(
        '• Keep this app open while you wait.\n'
        '• You will get a notification when it is your turn.\n'
        '• All meetings are virtual — there is no office visit.',
        style: TextStyle(height: 1.6, color: AppColors.ink),
      ),
    );
  }
}
