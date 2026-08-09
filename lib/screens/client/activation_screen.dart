import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

/// Entry point for paying clients. Access requires the one-time code the firm
/// issues after the Docketwise contract is signed and paid.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      await state.activate(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        code: _codeCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.clientHome, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.lastError ?? 'Activation failed.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.navyMid, Color(0xFF0A1628)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            children: [
              const BrandHeader(light: true),
              const SizedBox(height: 36),
              Text(
                'Client access',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(color: Colors.white, fontSize: 34),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the activation code we emailed you after your agreement '
                'was signed. It works once and links this device to your case team.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Enter the email we have on file'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Activation code',
                        hintText: 'ALF-XXXXXX',
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.trim().length < 4)
                          ? 'Enter your activation code'
                          : null,
                    ),
                    const SizedBox(height: 26),
                    PrimaryButton(
                      label: 'Activate my access',
                      gold: true,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Not a client yet? Start with a free consultation at '
                'accesslawoffice.com — we will send your code once you are signed up.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.staffLogin),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.goldLight,
                  ),
                  child: const Text('Firm staff sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
