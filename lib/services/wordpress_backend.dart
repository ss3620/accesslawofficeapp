import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/client_models.dart';
import 'app_backend.dart';
import 'firebase_chat_service.dart';
import 'session_storage.dart';
import 'wp_api_client.dart';
import 'wp_config.dart';

/// WordPress for lobby / auth / appointments; optional Firebase for chat + push.
class WordpressBackend implements AppBackend {
  WordpressBackend({
    WpApiClient? client,
    SessionStorage? storage,
    FirebaseChatService? chat,
    this.pollInterval = const Duration(seconds: 2),
  })  : _api = client ?? WpApiClient(),
        _storage = storage ?? SessionStorage(),
        _chat = chat;

  final WpApiClient _api;
  final SessionStorage _storage;
  final FirebaseChatService? _chat;
  final Duration pollInterval;

  final Map<String, int> _visitByClient = {};

  bool get usesFirebaseChat => _chat != null;

  @override
  bool get isRemote => true;

  @override
  Future<void> initialize() async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _api.accessToken = token;
    }
  }

  Future<void> _persistToken(String? token) async {
    _api.accessToken = token;
    if (token == null || token.isEmpty) {
      await _storage.clearAccessToken();
    } else {
      await _storage.saveAccessToken(token);
    }
  }

  Future<void> _bindClientChat(ClientProfile client) async {
    final chat = _chat;
    if (chat == null) return;
    await chat.ensureClientSession(
      wpClientId: client.id,
      name: client.name,
      email: client.email,
    );
  }

  // —— Client activation ——

  @override
  Future<ClientProfile> redeemActivationCode({
    required String name,
    required String email,
    required String code,
  }) async {
    await _persistToken(null);
    await _chat?.signOut();

    final data = await _api.post('/clients/activate', body: {
      'name': name,
      'email': email,
      'code': code,
    }) as Map<String, dynamic>;

    final token = data['token'] as String?;
    final clientMap = data['client'] as Map<String, dynamic>?;
    if (token == null || clientMap == null) {
      throw BackendException('Activation failed. Please try again.');
    }
    await _persistToken(token);
    final client = ClientProfile.fromMap(clientMap['id'] as String, clientMap);
    try {
      await _bindClientChat(client);
      final chat = _chat;
      if (chat != null) {
        await chat.sendMessage(
          threadId: client.threadId,
          senderId: 'system',
          senderName: 'Access Law Firm',
          senderRole: SenderRole.system,
          body:
              'Welcome ${client.name}. Your attorney and receptionist can see this chat. '
              'Send a message any time and we will respond during office hours.',
        );
      }
    } on BackendException {
      rethrow;
    } catch (error) {
      throw BackendException(
        'Account created, but chat could not start. Enable Anonymous sign-in '
        'in Firebase Authentication. ($error)',
      );
    }
    return client;
  }

  @override
  Future<ClientProfile?> loadClient(String clientId) async {
    try {
      final data =
          await _api.get('/clients/$clientId') as Map<String, dynamic>;
      final client = ClientProfile.fromMap(clientId, data);
      await _bindClientChat(client);
      return client;
    } on BackendException {
      return null;
    }
  }

  // —— Chat ——

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    final chat = _chat;
    if (chat != null) {
      return chat.watchMessages(threadId);
    }
    return _watchMessagesFromWp(threadId);
  }

  Stream<List<ChatMessage>> _watchMessagesFromWp(String threadId) async* {
    yield await _fetchMessages(threadId);
    yield* Stream.periodic(pollInterval)
        .asyncMap((_) => _fetchMessages(threadId));
  }

  Future<List<ChatMessage>> _fetchMessages(String threadId) async {
    final data = await _api.get('/threads/$threadId/messages')
        as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    return items.map((raw) {
      final map = raw as Map<String, dynamic>;
      return ChatMessage.fromMap(map['id'] as String, map);
    }).toList();
  }

  @override
  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String body,
    bool urgent = false,
  }) async {
    final chat = _chat;
    if (chat != null) {
      await chat.sendMessage(
        threadId: threadId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        body: body,
        urgent: urgent,
      );
      return;
    }
    await _api.post('/threads/$threadId/messages', body: {
      'body': body,
      'urgent': urgent,
    });
  }

  // —— Video lobby ——

  @override
  Stream<LobbyState> watchLobby(String clientId) async* {
    yield await _fetchLobby(clientId);
    yield* Stream.periodic(pollInterval).asyncMap((_) => _fetchLobby(clientId));
  }

  Future<LobbyState> _fetchLobby(String clientId) async {
    final data = await _api.get('/lobby/clients/$clientId')
        as Map<String, dynamic>;
    final visitId = data['visitId'];
    if (visitId != null) {
      _visitByClient[clientId] = int.tryParse('$visitId') ?? 0;
    }
    return LobbyState.fromMap(clientId, data);
  }

  @override
  Future<void> enterLobby(ClientProfile client) async {
    final data = await _api.post('/lobby/clients/${client.id}')
        as Map<String, dynamic>;
    final visitId = data['visitId'];
    if (visitId != null) {
      _visitByClient[client.id] = int.tryParse('$visitId') ?? 0;
    }
    final chat = _chat;
    if (chat != null) {
      await chat.sendMessage(
        threadId: client.threadId,
        senderId: 'system',
        senderName: 'Access Law Firm',
        senderRole: SenderRole.system,
        body: '${client.name} entered the video lobby.',
      );
    }
  }

  @override
  Future<void> leaveLobby(String clientId) async {
    await _api.post('/lobby/clients/$clientId/leave');
    _visitByClient.remove(clientId);
  }

  @override
  Future<void> setLobbyStatus(String clientId, LobbyStatus status) async {
    var visitId = _visitByClient[clientId] ?? 0;
    if (visitId == 0) {
      final lobby = await _fetchLobby(clientId);
      visitId = _visitByClient[clientId] ?? 0;
      if (visitId == 0 && lobby.status == LobbyStatus.idle) {
        throw BackendException('Client is not in the lobby.');
      }
    }

    final action = switch (status) {
      LobbyStatus.ready => 'ready',
      LobbyStatus.withAttorney => 'transfer',
      LobbyStatus.completed => 'complete',
      LobbyStatus.idle => 'dismiss',
      LobbyStatus.waiting => null,
    };

    if (action == null || visitId == 0) return;

    await setQueueAction(
      visitId: visitId,
      action: action,
      appClientId: clientId,
    );
  }

  @override
  Stream<LobbyQueueSnapshot> watchQueue() async* {
    yield await _fetchQueue();
    yield* Stream.periodic(pollInterval).asyncMap((_) => _fetchQueue());
  }

  Future<LobbyQueueSnapshot> _fetchQueue() async {
    final data = await _api.get('/queue') as Map<String, dynamic>;
    final snapshot = LobbyQueueSnapshot.fromMap(data);
    for (final visit in snapshot.items) {
      final clientId = visit.appClientId;
      if (clientId != null && clientId.isNotEmpty) {
        _visitByClient[clientId] = visit.id;
      }
    }
    return snapshot;
  }

  @override
  Future<void> setQueueAction({
    required int visitId,
    required String action,
    String? appClientId,
  }) async {
    await _api.post('/queue/$visitId/actions', body: {'action': action});

    final chat = _chat;
    final clientId = appClientId;
    if (chat == null || clientId == null || clientId.isEmpty) return;

    final body = switch (action) {
      'ready' => 'Your receptionist is ready. Join the video call.',
      'transfer' => 'You are being transferred. Your attorney is ready.',
      'complete' => 'This session is complete.',
      _ => null,
    };
    if (body == null) return;

    await chat.sendMessage(
      threadId: clientId,
      senderId: 'system',
      senderName: 'Access Law Firm',
      senderRole: SenderRole.system,
      body: body,
    );
  }

  // —— Appointments ——

  @override
  Future<void> requestAppointment({
    required ClientProfile client,
    required String preferredWindow,
    required String note,
  }) async {
    await _api.post('/appointments', body: {
      'clientId': client.id,
      'preferredWindow': preferredWindow,
      'note': note,
    });
    final chat = _chat;
    if (chat != null) {
      await chat.sendMessage(
        threadId: client.threadId,
        senderId: 'system',
        senderName: 'Access Law Firm',
        senderRole: SenderRole.system,
        body: 'Appointment requested for $preferredWindow.',
      );
    }
  }

  @override
  Stream<List<AppointmentRequest>> watchAppointments({String? clientId}) async* {
    yield await _fetchAppointments(clientId);
    yield* Stream.periodic(pollInterval)
        .asyncMap((_) => _fetchAppointments(clientId));
  }

  Future<List<AppointmentRequest>> _fetchAppointments(String? clientId) async {
    final query = clientId == null ? null : {'clientId': clientId};
    final data =
        await _api.get('/appointments', query: query) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    return items.map((raw) {
      final map = raw as Map<String, dynamic>;
      return AppointmentRequest.fromMap(map['id'] as String, map);
    }).toList();
  }

  @override
  Future<void> setAppointmentStatus(String id, AppointmentStatus status) async {
    await _api.patch('/appointments/$id', body: {'status': status.name});
  }

  // —— Staff ——

  @override
  Future<StaffProfile?> staffSignIn(String email, String password) async {
    final data = await _api.post('/auth/login', body: {
      'email': email.trim(),
      'username': email.trim(),
      'password': password,
    }) as Map<String, dynamic>;

    final token = data['token'] as String?;
    final staffMap = data['staff'] is Map<String, dynamic>
        ? data['staff'] as Map<String, dynamic>
        : null;
    final id = staffMap?['id']?.toString();
    if (token == null ||
        token.isEmpty ||
        staffMap == null ||
        id == null ||
        id.isEmpty) {
      return null;
    }
    await _persistToken(token);
    final staff = StaffProfile.fromMap(id, staffMap);
    try {
      await _storage.saveStaffProfile(staff);
      await _storage.saveStaffEmail(staff.email);
    } catch (error) {
      debugPrint('Could not persist staff session: $error');
    }

    final chat = _chat;
    if (chat != null) {
      try {
        await chat.ensureStaffSession(
          email: email.trim(),
          password: password,
          displayName: staff.name,
          role: staff.role,
        );
      } catch (error) {
        debugPrint('Firebase staff chat session skipped: $error');
      }
    }
    return staff;
  }

  @override
  Future<StaffProfile?> restoreStaffSession({String? savedEmail}) async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    _api.accessToken = token;

    final cached = await _storage.getStaffProfile();
    for (final path in ['/auth/me', '/staff/me']) {
      try {
        final data = await _api.get(path) as Map<String, dynamic>;
        final raw = data['staff'] is Map<String, dynamic>
            ? data['staff'] as Map<String, dynamic>
            : data;
        final id = (raw['id'] ?? savedEmail ?? '').toString();
        if (id.isEmpty || raw['email'] == null && raw['name'] == null) {
          continue;
        }
        final staff = StaffProfile.fromMap(id, raw);
        await _storage.saveStaffProfile(staff);
        return staff;
      } on BackendException {
        continue;
      }
    }

    return cached;
  }

  @override
  Stream<List<ClientProfile>> watchClients() async* {
    yield await _fetchClients();
    yield* Stream.periodic(pollInterval).asyncMap((_) => _fetchClients());
  }

  Future<List<ClientProfile>> _fetchClients() async {
    final data = await _api.get('/clients') as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    return items.map((raw) {
      final map = raw as Map<String, dynamic>;
      return ClientProfile.fromMap(map['id'] as String, map);
    }).toList();
  }

  @override
  Stream<List<ActivationCode>> watchActivationCodes() async* {
    yield await _fetchCodes();
    yield* Stream.periodic(pollInterval).asyncMap((_) => _fetchCodes());
  }

  Future<List<ActivationCode>> _fetchCodes() async {
    final data =
        await _api.get('/activation-codes') as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const []);
    return items.map((raw) {
      final map = raw as Map<String, dynamic>;
      return ActivationCode.fromMap(map['code'] as String, map);
    }).toList();
  }

  @override
  Future<ActivationCode> createActivationCode(String email) async {
    final data = await _api.post('/activation-codes', body: {
      'email': email,
    }) as Map<String, dynamic>;
    return ActivationCode.fromMap(data['code'] as String, data);
  }

  @override
  Future<void> saveZoomLinks({
    required String receptionZoomUrl,
    required String attorneyZoomUrl,
  }) async {
    await _api.put('/admin/settings', body: {
      'receptionZoomUrl': receptionZoomUrl,
      'attorneyZoomUrl': attorneyZoomUrl,
    });
  }

  @override
  Future<Map<String, String>> loadZoomLinks() async {
    final data =
        await _api.get('/admin/settings') as Map<String, dynamic>;
    return {
      'receptionZoomUrl': (data['receptionZoomUrl'] ?? '') as String,
      'attorneyZoomUrl': (data['attorneyZoomUrl'] ?? '') as String,
    };
  }

  @override
  Future<void> registerPushToken(String ownerId, String token) async {
    final chat = _chat;
    if (chat != null) {
      await chat.registerPushToken(ownerId, token);
      return;
    }
    await _api.post('/device/register', body: {
      'ownerId': ownerId,
      'token': token,
      'platform': 'mobile',
    });
  }

  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Best-effort.
    }
    await _chat?.signOut();
    await _persistToken(null);
    await _storage.clearStaffSession();
  }
}

/// Whether the app should prefer WordPress over Firebase/local.
bool get useWordpressBackend => WpConfig.isConfigured;
