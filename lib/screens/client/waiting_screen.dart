import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      await context.read<AppState>().pollVisit();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _joinMeeting(bool attorney) async {
    final app = context.read<AppState>();
    final url = attorney
        ? app.config?.attorneyZoomUrl
        : app.config?.receptionZoomUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting link is not configured yet.')),
      );
      return;
    }
    await app.markJoined();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _statusColor(VisitStatus status) => switch (status) {
        VisitStatus.waiting => AppColors.waiting,
        VisitStatus.ready => AppColors.ready,
        VisitStatus.inMeeting => AppColors.inMeeting,
        VisitStatus.withAttorney => AppColors.attorney,
        VisitStatus.completed => AppColors.muted,
        VisitStatus.dismissed => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final visit = app.activeVisit;

    if (visit == null) {
      return ScreenScaffold(
        title: 'Waiting room',
        child: Center(
          child: PrimaryButton(
            label: 'Return to lobby',
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/client/home'),
          ),
        ),
      );
    }

    final ready = visit.status == VisitStatus.ready ||
        visit.status == VisitStatus.inMeeting;
    final attorney = visit.status == VisitStatus.withAttorney;
    final ended = visit.status == VisitStatus.completed ||
        visit.status == VisitStatus.dismissed;

    return ScreenScaffold(
      title: 'Waiting room',
      actions: [
        IconButton(
          tooltip: 'End session',
          onPressed: () async {
            await app.clientLogout();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: visit.status.label,
                      color: _statusColor(visit.status),
                    ),
                    const Spacer(),
                    if (visit.status == VisitStatus.waiting)
                      Text(
                        'Position #${visit.position}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  visit.fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(visit.matter, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (visit.status == VisitStatus.waiting) ...[
            Text(
              'Please keep this app open',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              '• Do not close or force-quit the app while waiting.\n'
              '• You will get a notification when the receptionist is ready.\n'
              '• Meetings are 100% virtual; no in-person appointments.',
              style: TextStyle(height: 1.55, color: AppColors.ink),
            ),
          ],
          if (ready) ...[
            Text(
              'Your receptionist is ready',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Join the reception meeting now. Stay nearby — you may be transferred to an attorney next.',
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Join Reception Zoom',
              gold: true,
              onPressed: () => _joinMeeting(false),
            ),
          ],
          if (attorney) ...[
            Text(
              'Your attorney is ready',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'If you are still in the reception meeting, leave it first, then join the attorney meeting.',
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Join Attorney Zoom',
              gold: true,
              onPressed: () => _joinMeeting(true),
            ),
          ],
          if (ended) ...[
            Text(
              visit.status == VisitStatus.completed
                  ? 'Visit completed'
                  : 'Visit dismissed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Back to start',
              onPressed: () async {
                await app.clientLogout();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (_) => false);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}