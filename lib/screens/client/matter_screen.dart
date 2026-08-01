import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class MatterScreen extends StatefulWidget {
  const MatterScreen({super.key});

  @override
  State<MatterScreen> createState() => _MatterScreenState();
}

class _MatterScreenState extends State<MatterScreen> {
  String? _selected;
  bool _loading = false;

  Future<void> _submit() async {
    if (_selected == null) return;
    final app = context.read<AppState>();
    app.draftMatter = _selected!;
    setState(() => _loading = true);
    try {
      await app.submitCheckIn();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/client/waiting',
        (route) => route.settings.name == '/client/home' || route.isFirst,
      );
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
    final matters = context.watch<AppState>().config?.matters ?? [];

    return ScreenScaffold(
      title: 'Matter type',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help today?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Select the matter that best matches your visit.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: matters.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final matter = matters[index];
                  final selected = _selected == matter;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = matter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.navy : AppColors.border,
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                matter,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle, color: AppColors.navy),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            PrimaryButton(
              label: 'Check in to lobby',
              loading: _loading,
              onPressed: _selected == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}