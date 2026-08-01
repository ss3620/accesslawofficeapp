import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late TextEditingController _receptionUrl;
  late TextEditingController _attorneyUrl;
  late TextEditingController _receptionNumber;
  late TextEditingController _attorneyNumber;
  late TextEditingController _receptionPass;
  late TextEditingController _attorneyPass;
  late TextEditingController _hours;
  bool _messaging = false;
  bool _voip = false;
  bool _sdk = false;
  VerifyMode _verifyMode = VerifyMode.none;
  bool _loading = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().config;
    _receptionUrl = TextEditingController(text: c?.receptionZoomUrl ?? '');
    _attorneyUrl = TextEditingController(text: c?.attorneyZoomUrl ?? '');
    _receptionNumber =
        TextEditingController(text: c?.receptionMeetingNumber ?? '');
    _attorneyNumber =
        TextEditingController(text: c?.attorneyMeetingNumber ?? '');
    _receptionPass = TextEditingController(text: c?.receptionPasscode ?? '');
    _attorneyPass = TextEditingController(text: c?.attorneyPasscode ?? '');
    _hours = TextEditingController(text: c?.hoursCopy ?? '');
    _messaging = c?.featureMessaging ?? false;
    _voip = c?.featureVoip ?? false;
    _sdk = c?.featureMeetingSdk ?? false;
    _verifyMode = c?.verifyMode ?? VerifyMode.none;
    _ready = true;
  }

  @override
  void dispose() {
    _receptionUrl.dispose();
    _attorneyUrl.dispose();
    _receptionNumber.dispose();
    _attorneyNumber.dispose();
    _receptionPass.dispose();
    _attorneyPass.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final current = app.config;
    if (current == null) return;
    setState(() => _loading = true);
    try {
      await app.saveAdminSettings(
        current.copyWith(
          receptionZoomUrl: _receptionUrl.text.trim(),
          attorneyZoomUrl: _attorneyUrl.text.trim(),
          receptionMeetingNumber: _receptionNumber.text.trim(),
          attorneyMeetingNumber: _attorneyNumber.text.trim(),
          receptionPasscode: _receptionPass.text.trim(),
          attorneyPasscode: _attorneyPass.text.trim(),
          hoursCopy: _hours.text.trim(),
          featureMessaging: _messaging,
          featureVoip: _voip,
          featureMeetingSdk: _sdk,
          verifyMode: _verifyMode,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ScreenScaffold(
      title: 'Lobby settings',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Reception Zoom', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _receptionUrl,
            decoration: const InputDecoration(labelText: 'Join URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _receptionNumber,
            decoration: const InputDecoration(labelText: 'Meeting number'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _receptionPass,
            decoration: const InputDecoration(labelText: 'Passcode'),
          ),
          const SizedBox(height: 20),
          Text('Attorney Zoom', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _attorneyUrl,
            decoration: const InputDecoration(labelText: 'Join URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _attorneyNumber,
            decoration: const InputDecoration(labelText: 'Meeting number'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _attorneyPass,
            decoration: const InputDecoration(labelText: 'Passcode'),
          ),
          const SizedBox(height: 20),
          Text('Hours copy (CST)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _hours,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Displayed hours'),
          ),
          const SizedBox(height: 20),
          Text('Verify mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<VerifyMode>(
            initialValue: _verifyMode,
            items: VerifyMode.values
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.name),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _verifyMode = v ?? VerifyMode.none),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Feature: messaging'),
            value: _messaging,
            onChanged: (v) => setState(() => _messaging = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Feature: VoIP calling'),
            value: _voip,
            onChanged: (v) => setState(() => _voip = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Feature: Zoom Meeting SDK'),
            value: _sdk,
            onChanged: (v) => setState(() => _sdk = v),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save settings',
            loading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}