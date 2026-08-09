import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../widgets/chat_view.dart';

class StaffClientDetailScreen extends StatelessWidget {
  const StaffClientDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ModalRoute.of(context)?.settings.arguments as ClientProfile?;
    final state = context.watch<AppState>();
    final staff = state.staff;

    if (client == null || staff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Client')),
        body: const Center(child: Text('No client selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(client.name)),
      body: StreamBuilder<List<ChatMessage>>(
        stream: state.threadFor(client.threadId),
        builder: (context, snapshot) {
          return ChatView(
            messages: snapshot.data ?? const [],
            currentRole: staff.role.senderRole,
            loading: snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData,
            onSend: (body) =>
                context.read<AppState>().sendStaffMessage(client.threadId, body),
          );
        },
      ),
    );
  }
}
