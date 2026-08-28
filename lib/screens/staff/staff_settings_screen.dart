import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

/// Everything the firm needs day to day that is not the queue: issue activation
/// codes, set the two Zoom rooms, and answer appointment requests.
class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  final _receptionCtrl = TextEditingController();
  final _attorneyCtrl = TextEditingController();
  bool _savingLinks = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final links = await context.read<AppState>().loadZoomLinks();
      if (!mounted) return;
      setState(() {
        _receptionCtrl.text = links['receptionZoomUrl'] ?? '';
        _attorneyCtrl.text = links['attorneyZoomUrl'] ?? '';
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _receptionCtrl.dispose();
    _attorneyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLinks() async {
    setState(() => _savingLinks = true);
    try {
      await context.read<AppState>().saveZoomLinks(
            receptionZoomUrl: _receptionCtrl.text.trim(),
            attorneyZoomUrl: _attorneyCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting links saved.')),
      );
    } finally {
      if (mounted) setState(() => _savingLinks = false);
    }
  }

  Future<void> _createCode() async {
    final emailCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New activation code'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Client email (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final code = await context.read<AppState>().createActivationCode(
          emailCtrl.text,
        );
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: code.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${code.code} copied — email it to the client.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Codes & settings')),
      body: ScrollScreenBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
            Text('Meeting rooms',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _receptionCtrl,
              enabled: _loaded,
              decoration: const InputDecoration(labelText: 'Reception Zoom link'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _attorneyCtrl,
              enabled: _loaded,
              decoration: const InputDecoration(labelText: 'Attorney Zoom link'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save meeting links',
              loading: _savingLinks,
              onPressed: _loaded ? _saveLinks : null,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text('Activation codes',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: _createCode,
                  icon: const Icon(Icons.add),
                  label: const Text('New code'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<ActivationCode>>(
              stream: state.staffCodes(),
              builder: (context, snapshot) {
                final codes = snapshot.data ?? const <ActivationCode>[];
                if (codes.isEmpty) {
                  return Text(
                    'No codes issued yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: codes
                      .map(
                        (code) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            code.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          subtitle: Text(
                            code.email.isEmpty ? 'Any client' : code.email,
                          ),
                          trailing: StatusPill(
                            label: code.used ? 'Used' : 'Available',
                            color:
                                code.used ? AppColors.muted : AppColors.success,
                          ),
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: code.code));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied.')),
                            );
                          },
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            Text('Appointment requests',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            StreamBuilder<List<AppointmentRequest>>(
              stream: state.staffAppointments(),
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <AppointmentRequest>[];
                if (requests.isEmpty) {
                  return Text(
                    'No requests yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: requests
                      .map(
                        (request) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SectionCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${request.clientName} · ${request.preferredWindow}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                StatusPill(
                                  label: request.sourceLabel,
                                  color: request.isWebsite
                                      ? AppColors.waiting
                                      : AppColors.navy,
                                ),
                                if (request.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(request.note),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(request.createdAt),
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    StatusPill(
                                      label: request.status.label,
                                      color: switch (request.status) {
                                        AppointmentStatus.confirmed =>
                                          AppColors.success,
                                        AppointmentStatus.declined =>
                                          AppColors.danger,
                                        AppointmentStatus.requested =>
                                          AppColors.waiting,
                                      },
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => state.setAppointmentStatus(
                                        request.id,
                                        AppointmentStatus.confirmed,
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                    TextButton(
                                      onPressed: () => state.setAppointmentStatus(
                                        request.id,
                                        AppointmentStatus.declined,
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}
