import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  static const _windows = [
    'As soon as the attorney is free',
    'Today, morning',
    'Today, afternoon',
    'Tomorrow, morning',
    'Tomorrow, afternoon',
    'This week, any time',
  ];

  String _window = _windows.first;
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await context.read<AppState>().requestAppointment(
            preferredWindow: _window,
            note: _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      _noteCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to your legal team.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Request an appointment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'When works for you?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Reception will confirm a time, or connect you sooner if the attorney is free.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            RadioGroup<String>(
              groupValue: _window,
              onChanged: (value) => setState(() => _window = value ?? _window),
              child: Column(
                children: _windows
                    .map(
                      (window) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: window,
                        title: Text(window),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Anything we should know? (optional)',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Send request',
              loading: _sending,
              onPressed: _submit,
            ),
            const SizedBox(height: 28),
            Text('Your requests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            StreamBuilder<List<AppointmentRequest>>(
              stream: state.clientAppointments(),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        request.preferredWindow,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
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
                                  ],
                                ),
                                if (request.note.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(request.note),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(request.createdAt),
                                  style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}
