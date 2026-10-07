import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/client_models.dart';
import '../../services/app_backend.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

/// Client side of the receptionist -> attorney handoff. Status is driven by
/// staff; the client just sees whose room to join.
class VideoLobbyScreen extends StatefulWidget {
  const VideoLobbyScreen({super.key});

  @override
  State<VideoLobbyScreen> createState() => _VideoLobbyScreenState();
}

class _VideoLobbyScreenState extends State<VideoLobbyScreen> {
  late final Stream<LobbyState> _lobby;
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _checkingIn = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _lobby = context.read<AppState>().clientLobby();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _join(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The meeting link is not set up yet.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
  }

  Future<void> _checkIn() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid mobile number so we can call you.'),
        ),
      );
      return;
    }
    setState(() => _checkingIn = true);
    try {
      await context.read<AppState>().enterLobby(phone: _phoneCtrl.text.trim());
    } on BackendException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check in. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _leave({bool pop = false}) async {
    setState(() => _leaving = true);
    try {
      await context.read<AppState>().leaveLobby();
      if (pop && mounted) Navigator.of(context).pop();
    } on BackendException catch (error) {
      if (pop && mounted) {
        Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Video lobby')),
      body: ScrollScreenBody(
        child: SafeArea(
          child: StreamBuilder<LobbyState>(
            stream: _lobby,
            builder: (context, snapshot) {
              final lobby = snapshot.data;
              if (lobby == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final waitingForLink = (lobby.status == LobbyStatus.ready &&
                      !lobby.canJoinReception) ||
                  (lobby.status == LobbyStatus.withAttorney &&
                      !lobby.canJoinAttorney);
              final canLeave = lobby.status == LobbyStatus.waiting ||
                  lobby.status == LobbyStatus.ready ||
                  lobby.status == LobbyStatus.withAttorney;

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
                            LobbyStatus.ready => lobby.canJoinReception
                                ? 'Reception is ready for you now.'
                                : 'Reception is ready, but the meeting link is not set yet. Stay in the app — we will update this when the link is available.',
                            LobbyStatus.withAttorney => lobby.canJoinAttorney
                                ? 'You have been transferred. Leave the reception call first, then join your attorney.'
                                : 'You have been transferred, but the attorney meeting link is not set yet. Stay in the app.',
                            LobbyStatus.completed =>
                              'This session is finished. Message us any time.',
                          },
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (lobby.status == LobbyStatus.idle) ...[
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Mobile phone number',
                        hintText: '(713) 555-0123',
                        helperText:
                            'If we miss you in the lobby, we will call this number.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Check in to the lobby',
                      loading: _checkingIn,
                      onPressed: _checkingIn ? null : _checkIn,
                    ),
                  ],
                  if (lobby.status == LobbyStatus.waiting) ...[
                    const _WaitingGuidance(),
                    const SizedBox(height: 20),
                  ],
                  if (lobby.canJoinReception) ...[
                    PrimaryButton(
                      label: 'Join reception call',
                      gold: true,
                      onPressed: () => _join(lobby.receptionZoomUrl),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (lobby.canJoinAttorney) ...[
                    PrimaryButton(
                      label: 'Join attorney call',
                      gold: true,
                      onPressed: () => _join(lobby.attorneyZoomUrl),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (waitingForLink)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Ask reception to save the Zoom links in Codes & settings.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  if (canLeave)
                    OutlinedButton(
                      onPressed: _leaving ? null : () => _leave(),
                      child: Text(_leaving ? 'Leaving…' : 'Leave the lobby'),
                    ),
                  if (lobby.status == LobbyStatus.completed)
                    PrimaryButton(
                      label: 'Back to home',
                      loading: _leaving,
                      onPressed: _leaving
                          ? null
                          : () => _leave(pop: true),
                    ),
                ],
              );
            },
          ),
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
