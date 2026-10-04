import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import 'common.dart';

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose what this phone should alert you about. Message text is never included.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New messages'),
            subtitle: Text(
              state.sessionKind == SessionKind.staff
                  ? 'Alert when a client writes in chat'
                  : 'Alert when your legal team writes in chat',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: state.notifyMessages,
            activeThumbColor: AppColors.navy,
            onChanged: (value) => state.setNotifyMessages(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Appointments'),
            subtitle: Text(
              state.sessionKind == SessionKind.staff
                  ? 'Alert when a client requests a time'
                  : 'Alert when a request is confirmed or declined',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: state.notifyAppointments,
            activeThumbColor: AppColors.navy,
            onChanged: (value) => state.setNotifyAppointments(value),
          ),
        ],
      ),
    );
  }
}
