import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/client_models.dart';
import '../../state/app_state.dart';
import '../../widgets/chat_view.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your legal team'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(26),
          child: Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Attorney + reception',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: state.clientMessages(),
        builder: (context, snapshot) {
          return ChatView(
            messages: snapshot.data ?? const [],
            currentRole: SenderRole.client,
            loading: snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData,
            onSend: (body) => context.read<AppState>().sendClientMessage(body),
          );
        },
      ),
    );
  }
}
