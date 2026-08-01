import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshQueue();
    });
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) context.read<AppState>().refreshQueue();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _color(VisitStatus s) => switch (s) {
        VisitStatus.waiting => AppColors.waiting,
        VisitStatus.ready => AppColors.ready,
        VisitStatus.inMeeting => AppColors.inMeeting,
        VisitStatus.withAttorney => AppColors.attorney,
        _ => AppColors.muted,
      };

  String _waitLabel(Visit visit) {
    final m = visit.waitDuration.inMinutes;
    if (m < 1) return '<1 min';
    return '$m min';
  }

  Future<void> _action(Visit visit, QueueAction action) async {
    final app = context.read<AppState>();
    try {
      await app.runQueueAction(visit.id, action);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final open = app.config?.isOpen ?? false;

    return ScreenScaffold(
      title: 'Live queue',
      actions: [
        if (app.isAdmin)
          IconButton(
            tooltip: 'Admin',
            onPressed: () => Navigator.of(context).pushNamed('/admin/home'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        IconButton(
          tooltip: 'Profile',
          onPressed: () => Navigator.of(context).pushNamed('/staff/profile'),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: app.refreshQueue,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          open ? 'Lobby is open' : 'Lobby is closed',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat('EEE, MMM d · h:mm a').format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: open,
                    activeThumbColor: AppColors.navy,
                    onChanged: (v) => app.setLobbyOpen(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${app.queue.length} active visits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (app.queue.isEmpty)
              const SectionCard(
                child: Text(
                  'No visitors in the lobby right now.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              ...app.queue.map((visit) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusPill(
                              label: visit.status.label,
                              color: _color(visit.status),
                            ),
                            const Spacer(),
                            Text(
                              _waitLabel(visit),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          visit.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${visit.matter} · ${visit.maskedPhone}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (visit.status == VisitStatus.waiting)
                              _ActionChip(
                                label: 'Ready',
                                onTap: () => _action(visit, QueueAction.ready),
                              ),
                            if (visit.status == VisitStatus.ready ||
                                visit.status == VisitStatus.inMeeting)
                              _ActionChip(
                                label: 'Transfer',
                                onTap: () =>
                                    _action(visit, QueueAction.transfer),
                              ),
                            _ActionChip(
                              label: 'Complete',
                              onTap: () =>
                                  _action(visit, QueueAction.complete),
                            ),
                            _ActionChip(
                              label: 'Dismiss',
                              danger: true,
                              onTap: () =>
                                  _action(visit, QueueAction.dismiss),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor:
          danger ? AppColors.danger.withValues(alpha: 0.1) : null,
      labelStyle: TextStyle(
        color: danger ? AppColors.danger : AppColors.navy,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}