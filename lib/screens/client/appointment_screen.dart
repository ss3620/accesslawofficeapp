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
  static const _days = ['Today', 'Tomorrow'];
  static const _times = [
    '9:00 AM',
    '9:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
  ];

  String _day = _days.first;
  String _time = _times.first;
  late final Stream<List<AppointmentRequest>> _requests;
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  String get _window => '$_day, $_time';

  @override
  void initState() {
    super.initState();
    _requests = context.read<AppState>().clientAppointments();
  }

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
        SnackBar(content: Text('Request sent for $_window.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request an appointment')),
      body: ScrollScreenBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'When works for you?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a 30-minute time between 9:00 AM and 4:00 PM. Reception will confirm it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: [
                  for (final day in _days)
                    ButtonSegment(value: day, label: Text(day)),
                ],
                selected: {_day},
                onSelectionChanged: (value) =>
                    setState(() => _day = value.first),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    ChoiceChip(
                      label: Text(time),
                      selected: _time == time,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _time = time),
                      selectedColor: AppColors.navy,
                      labelStyle: TextStyle(
                        color: _time == time ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: $_window',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
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
                onPressed: _sending ? null : _submit,
              ),
              const SizedBox(height: 28),
              Text(
                'Your requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<AppointmentRequest>>(
                stream: _requests,
                builder: (context, snapshot) {
                  final requests =
                      snapshot.data ?? const <AppointmentRequest>[];
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
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
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
