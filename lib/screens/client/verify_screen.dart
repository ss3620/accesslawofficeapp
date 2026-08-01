import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _otpCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final app = context.read<AppState>();
    final phone = '${app.draftCountry}${app.draftPhone}';
    setState(() => _loading = true);
    try {
      await app.api.sendOtp(phone);
      setState(() => _otpSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo OTP: 123456')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final app = context.read<AppState>();
    final mode = app.config?.verifyMode ?? VerifyMode.none;
    setState(() => _loading = true);
    try {
      if (mode == VerifyMode.sms || mode == VerifyMode.smsCaptcha) {
        final phone = '${app.draftCountry}${app.draftPhone}';
        final ok = await app.api.verifyOtp(phone, _otpCtrl.text.trim());
        if (!ok) throw StateError('Invalid verification code');
      }
      if (mode == VerifyMode.captcha || mode == VerifyMode.smsCaptcha) {
        final ok = await app.api.verifyCaptcha(_captchaCtrl.text);
        if (!ok) throw StateError('CAPTCHA failed');
      }
      if (!mounted) return;
      Navigator.of(context).pushNamed('/client/matter');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppState>().config?.verifyMode ?? VerifyMode.none;
    final needsSms = mode == VerifyMode.sms || mode == VerifyMode.smsCaptcha;
    final needsCaptcha =
        mode == VerifyMode.captcha || mode == VerifyMode.smsCaptcha;

    return ScreenScaffold(
      title: 'Verify',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm you are human',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Verification mode matches the website settings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (needsSms) ...[
              PrimaryButton(
                label: _otpSent ? 'Resend code' : 'Send SMS code',
                onPressed: _loading ? null : _sendOtp,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
              const SizedBox(height: 14),
            ],
            if (needsCaptcha) ...[
              TextField(
                controller: _captchaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Type ACCESS to continue',
                ),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: 'Continue',
              loading: _loading,
              onPressed: _verify,
            ),
          ],
        ),
      ),
    );
  }
}