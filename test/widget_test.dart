import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:access_law_office/models/client_models.dart';
import 'package:access_law_office/screens/client/activation_screen.dart';
import 'package:access_law_office/services/app_backend.dart';
import 'package:access_law_office/services/local_backend.dart';
import 'package:access_law_office/state/app_state.dart';
import 'package:access_law_office/theme/app_theme.dart';

void main() {
  testWidgets('activation screen asks for name, email and code',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(backend: LocalBackend()),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ActivationScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Access Law Firm'), findsWidgets);
    expect(find.text('Client access'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Activation code'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Firm staff sign in'), findsOneWidget);
  });

  group('LocalBackend', () {
    late LocalBackend backend;

    setUp(() async {
      backend = LocalBackend();
      await backend.initialize();
    });

    test('an activation code works exactly once', () async {
      final client = await backend.redeemActivationCode(
        name: 'Test Client',
        email: 'client@example.com',
        code: 'ALF-DEMO',
      );
      expect(client.active, isTrue);
      expect(client.threadId, client.id);

      await expectLater(
        backend.redeemActivationCode(
          name: 'Someone Else',
          email: 'other@example.com',
          code: 'ALF-DEMO',
        ),
        throwsA(isA<BackendException>()),
      );
    });

    test('unknown codes are rejected', () async {
      await expectLater(
        backend.redeemActivationCode(
          name: 'Walk In',
          email: 'walkin@example.com',
          code: 'NOT-A-CODE',
        ),
        throwsA(isA<BackendException>()),
      );
    });

    test('lobby moves from waiting to reception to attorney', () async {
      final code = await backend.createActivationCode('lobby@example.com');
      final client = await backend.redeemActivationCode(
        name: 'Lobby Client',
        email: 'lobby@example.com',
        code: code.code,
      );

      final states = <LobbyStatus>[];
      final sub = backend
          .watchLobby(client.id)
          .listen((lobby) => states.add(lobby.status));

      await backend.enterLobby(client);
      await backend.setLobbyStatus(client.id, LobbyStatus.ready);
      await backend.setLobbyStatus(client.id, LobbyStatus.withAttorney);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, containsAllInOrder([
        LobbyStatus.waiting,
        LobbyStatus.ready,
        LobbyStatus.withAttorney,
      ]));
    });

    test('staff sign in requires a known account', () async {
      final staff = await backend.staffSignIn(
        'reception@accesslawfirm.com',
        'reception123',
      );
      expect(staff?.role, StaffRole.receptionist);

      final bad = await backend.staffSignIn(
        'reception@accesslawfirm.com',
        'wrong',
      );
      expect(bad, isNull);
    });

    test('staff stay signed in after restore', () async {
      final signedIn = await backend.staffSignIn(
        'reception@accesslawfirm.com',
        'reception123',
      );
      expect(signedIn, isNotNull);

      final restored = await backend.restoreStaffSession(
        savedEmail: 'reception@accesslawfirm.com',
      );
      expect(restored?.id, signedIn!.id);
      expect(restored?.role, StaffRole.receptionist);
    });

    test('unread count only includes client messages after last read', () {
      final now = DateTime(2026, 8, 29, 12);
      final messages = [
        ChatMessage(
          id: '1',
          senderId: 'c1',
          senderRole: SenderRole.client,
          senderName: 'Client',
          body: 'Hello',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          id: '2',
          senderId: 's1',
          senderRole: SenderRole.receptionist,
          senderName: 'Front Desk',
          body: 'Hi',
          createdAt: now.subtract(const Duration(minutes: 3)),
        ),
        ChatMessage(
          id: '3',
          senderId: 'c1',
          senderRole: SenderRole.client,
          senderName: 'Client',
          body: 'Are you there?',
          createdAt: now,
        ),
      ];
      expect(AppState.countUnreadClientMessages(messages, null), 2);
      expect(
        AppState.countUnreadClientMessages(
          messages,
          now.subtract(const Duration(minutes: 1)),
        ),
        1,
      );
    });
  });
}
