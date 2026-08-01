import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _country = '+1';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _ctrl.text = app.draftPhone;
    _country = app.draftCountry;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _continue() {
    final app = context.read<AppState>();
    final mode = app.config?.verifyMode ?? VerifyMode.none;

    // Skip phone when SMS is off (parity with web `none` / captcha-only).
    if (mode == VerifyMode.none) {
      app.draftPhone = _ctrl.text.trim().isEmpty ? '0000000000' : _ctrl.text.trim();
      app.draftCountry = _country;
      Navigator.of(context).pushNamed('/client/matter');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    app.draftPhone = _ctrl.text.trim();
    app.draftCountry = _country;

    if (mode == VerifyMode.captcha) {
      Navigator.of(context).pushNamed('/client/verify');
    } else {
      Navigator.of(context).pushNamed('/client/verify');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().config?.verifyMode ?? VerifyMode.none;
    final smsRequired =
        mode == VerifyMode.sms || mode == VerifyMode.smsCaptcha;

    return ScreenScaffold(
      title: 'Phone number',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                smsRequired
                    ? 'Enter a mobile number for verification'
                    : 'Phone number (optional)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'We support US (+1) and India (+91).',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      initialValue: _country,
                      decoration: const InputDecoration(labelText: 'Code'),
                      items: const [
                        DropdownMenuItem(value: '+1', child: Text('+1')),
                        DropdownMenuItem(value: '+91', child: Text('+91')),
                      ],
                      onChanged: (v) => setState(() => _country = v ?? '+1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                      ),
                      validator: (v) {
                        if (!smsRequired && (v == null || v.isEmpty)) {
                          return null;
                        }
                        final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (_country == '+1' && digits.length != 10) {
                          return 'Enter a 10-digit US number';
                        }
                        if (_country == '+91' && digits.length != 10) {
                          return 'Enter a 10-digit Indian number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const Spacer(),
              PrimaryButton(label: 'Continue', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }
}