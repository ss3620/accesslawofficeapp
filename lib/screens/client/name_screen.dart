import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl.text = context.read<AppState>().draftName;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Your name',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is your full legal name?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the name you use on immigration documents.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Enter your full name';
                  }
                  return null;
                },
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  context.read<AppState>().draftName = _ctrl.text.trim();
                  Navigator.of(context).pushNamed('/client/phone');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}