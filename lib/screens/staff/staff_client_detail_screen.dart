import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../widgets/chat_view.dart';

class StaffClientDetailScreen extends StatefulWidget {
  const StaffClientDetailScreen({super.key});

  @override
  State<StaffClientDetailScreen> createState() =>
      _StaffClientDetailScreenState();
}

class _StaffClientDetailScreenState extends State<StaffClientDetailScreen> {
  String? _markedThreadId;

  void _markRead(ClientProfile client, List<ChatMessage> messages) {
    if (_markedThreadId == client.threadId && messages.isEmpty) return;
    _markedThreadId = client.threadId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().markThreadRead(
            client.threadId,
            messages: messages,
          );
    });
  }

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
          final messages = snapshot.data ?? const <ChatMessage>[];
          if (snapshot.hasData) {
            _markRead(client, messages);
          }
          return ChatView(
            messages: messages,
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
