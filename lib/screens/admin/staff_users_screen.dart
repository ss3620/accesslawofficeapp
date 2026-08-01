import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../rbac/roles.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';

class StaffUsersScreen extends StatefulWidget {
  const StaffUsersScreen({super.key});

  @override
  State<StaffUsersScreen> createState() => _StaffUsersScreenState();
}

class _StaffUsersScreenState extends State<StaffUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshStaff();
    });
  }

  Future<void> _showCreateDialog() async {
    final userCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create receptionist'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Temporary password'),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true || !mounted) return;
    try {
      await context.read<AppState>().createReceptionist(
            username: userCtrl.text.trim(),
            email: emailCtrl.text.trim(),
            password: passCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receptionist created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AppState>().staffUsers;

    return ScreenScaffold(
      title: 'Staff users',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add receptionist'),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: staff.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = staff[index];
          return SectionCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${user.username} · ${user.email}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      StatusPill(
                        label: user.active
                            ? user.role.label
                            : 'Inactive · ${user.role.label}',
                        color: user.active
                            ? (user.role == AppRole.admin
                                ? AppColors.gold
                                : AppColors.navy)
                            : AppColors.muted,
                      ),
                    ],
                  ),
                ),
                if (user.role == AppRole.receptionist && user.active)
                  IconButton(
                    tooltip: 'Deactivate',
                    onPressed: () async {
                      await context.read<AppState>().deactivateStaff(user.id);
                    },
                    icon: const Icon(Icons.person_off_outlined),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}