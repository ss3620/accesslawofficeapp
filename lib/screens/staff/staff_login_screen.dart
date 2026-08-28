import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      await state.staffSignIn(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.staffHome, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.lastError ?? 'Sign in failed.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = context.read<AppState>().usesLiveBackend;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff sign in')),
      body: ScrollScreenBody(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
            const BrandHeader(compact: true),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Work email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Sign in',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            if (!live) ...[
              const SizedBox(height: 26),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demo accounts',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'reception@accesslawfirm.com / reception123\n'
                      'attorney@accesslawfirm.com / attorney123\n'
                      'admin@accesslawfirm.com / admin123',
                      style: TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
