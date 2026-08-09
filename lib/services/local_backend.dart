import 'dart:async';
import 'dart:math';

import '../models/client_models.dart';
import 'app_backend.dart';

/// In-memory backend so the app runs (and demos) before the firm's Firebase
/// project exists. Data resets when the process restarts.
class LocalBackend implements AppBackend {
  final _rng = Random();

  final Map<String, ActivationCode> _codes = {};
  final Map<String, ClientProfile> _clients = {};
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, LobbyState> _lobbies = {};
  final Map<String, AppointmentRequest> _appointments = {};
  final Map<String, StaffProfile> _staff = {};
  final Map<String, String> _staffPasswords = {};

  String _receptionZoomUrl = 'https://zoom.us/j/1111111111';
  String _attorneyZoomUrl = 'https://zoom.us/j/2222222222';

  final _clientsCtrl = StreamController<List<ClientProfile>>.broadcast();
  final _codesCtrl = StreamController<List<ActivationCode>>.broadcast();
  final _appointmentsCtrl =
      StreamController<List<AppointmentRequest>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageCtrls = {};
  final Map<String, StreamController<LobbyState>> _lobbyCtrls = {};

  @override
  bool get isRemote => false;

  @override
  Future<void> initialize() async {
    _staff['staff-reception'] = const StaffProfile(
      id: 'staff-reception',
      name: 'Front Desk',
      email: 'reception@accesslawfirm.com',
      role: StaffRole.receptionist,
    );
    _staff['staff-attorney'] = const StaffProfile(
      id: 'staff-attorney',
      name: 'Attorney',
      email: 'attorney@accesslawfirm.com',
      role: StaffRole.attorney,
    );
    _staff['staff-admin'] = const StaffProfile(
      id: 'staff-admin',
      name: 'Office Admin',
      email: 'admin@accesslawfirm.com',
      role: StaffRole.admin,
    );
    _staffPasswords['reception@accesslawfirm.com'] = 'reception123';
    _staffPasswords['attorney@accesslawfirm.com'] = 'attorney123';
    _staffPasswords['admin@accesslawfirm.com'] = 'admin123';

    _codes['ALF-DEMO'] = ActivationCode(
      code: 'ALF-DEMO',
      email: '',
      used: false,
      createdAt: DateTime.now(),
    );
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(999)}';

  void _pushClients() => _clientsCtrl.add(_clients.values.toList());
  void _pushCodes() => _codesCtrl.add(_codes.values.toList());
  void _pushAppointments() {
    final list = _appointments.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _appointmentsCtrl.add(list);
  }

  void _pushMessages(String threadId) {
    _messageCtrls[threadId]?.add(List.of(_messages[threadId] ?? const []));
  }

  void _pushLobby(String clientId) {
    _lobbyCtrls[clientId]?.add(_lobbies[clientId] ?? LobbyState.empty(clientId));
  }

  @override
  Future<ClientProfile> redeemActivationCode({
    required String name,
    required String email,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final normalized = code.trim().toUpperCase();
    final record = _codes[normalized];
    if (record == null) {
      throw BackendException('That activation code was not recognized.');
    }
    if (record.used) {
      final existing = _clients[record.clientId];
      if (existing != null && existing.email == email.trim().toLowerCase()) {
        return existing;
      }
      throw BackendException('That activation code has already been used.');
    }
    if (record.email.isNotEmpty &&
        record.email.toLowerCase() != email.trim().toLowerCase()) {
      throw BackendException('This code was issued to a different email.');
    }

    final id = 'client-${_id()}';
    final client = ClientProfile(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      threadId: id,
      active: true,
      activationCode: normalized,
      createdAt: DateTime.now(),
    );
    _clients[id] = client;
    _codes[normalized] = ActivationCode(
      code: normalized,
      email: client.email,
      used: true,
      createdAt: record.createdAt,
      clientId: id,
    );
    _messages[client.threadId] = [
      ChatMessage(
        id: _id(),
        senderId: 'system',
        senderRole: SenderRole.system,
        senderName: 'Access Law Firm',
        body:
            'Welcome ${client.name}. Your attorney and receptionist can see this chat. '
            'Send a message any time and we will respond during office hours.',
        createdAt: DateTime.now(),
      ),
    ];
    _lobbies[id] = LobbyState(
      clientId: id,
      status: LobbyStatus.idle,
      receptionZoomUrl: _receptionZoomUrl,
      attorneyZoomUrl: _attorneyZoomUrl,
      updatedAt: DateTime.now(),
    );
    _pushClients();
    _pushCodes();
    return client;
  }

  @override
  Future<ClientProfile?> loadClient(String clientId) async => _clients[clientId];

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    final ctrl = _messageCtrls.putIfAbsent(
      threadId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    scheduleMicrotask(() => _pushMessages(threadId));
    return ctrl.stream;
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
    final list = _messages.putIfAbsent(threadId, () => []);
    list.add(
      ChatMessage(
        id: _id(),
        senderId: senderId,
        senderRole: senderRole,
        senderName: senderName,
        body: body,
        createdAt: DateTime.now(),
        urgent: urgent,
      ),
    );
    _pushMessages(threadId);
  }

  @override
  Stream<LobbyState> watchLobby(String clientId) {
    final ctrl = _lobbyCtrls.putIfAbsent(
      clientId,
      () => StreamController<LobbyState>.broadcast(),
    );
    scheduleMicrotask(() => _pushLobby(clientId));
    return ctrl.stream;
  }

  @override
  Future<void> enterLobby(ClientProfile client) async {
    final waiting = _lobbies.values
        .where((l) => l.status == LobbyStatus.waiting)
        .length;
    _lobbies[client.id] = LobbyState(
      clientId: client.id,
      status: LobbyStatus.waiting,
      receptionZoomUrl: _receptionZoomUrl,
      attorneyZoomUrl: _attorneyZoomUrl,
      updatedAt: DateTime.now(),
      position: waiting + 1,
    );
    _pushLobby(client.id);
    await sendMessage(
      threadId: client.threadId,
      senderId: 'system',
      senderName: 'Access Law Firm',
      senderRole: SenderRole.system,
      body: '${client.name} entered the video lobby.',
    );
  }

  @override
  Future<void> leaveLobby(String clientId) async {
    final current = _lobbies[clientId] ?? LobbyState.empty(clientId);
    _lobbies[clientId] = current.copyWith(status: LobbyStatus.idle, position: 0);
    _pushLobby(clientId);
  }

  @override
  Future<void> setLobbyStatus(String clientId, LobbyStatus status) async {
    final current = _lobbies[clientId] ??
        LobbyState(
          clientId: clientId,
          status: LobbyStatus.idle,
          receptionZoomUrl: _receptionZoomUrl,
          attorneyZoomUrl: _attorneyZoomUrl,
          updatedAt: DateTime.now(),
        );
    _lobbies[clientId] = current.copyWith(
      status: status,
      receptionZoomUrl: _receptionZoomUrl,
      attorneyZoomUrl: _attorneyZoomUrl,
    );
    _pushLobby(clientId);

    final client = _clients[clientId];
    if (client != null && status != LobbyStatus.idle) {
      await sendMessage(
        threadId: client.threadId,
        senderId: 'system',
        senderName: 'Access Law Firm',
        senderRole: SenderRole.system,
        body: switch (status) {
          LobbyStatus.ready => 'Your receptionist is ready. Join the video call.',
          LobbyStatus.withAttorney =>
            'You are being transferred. Your attorney is ready.',
          LobbyStatus.completed => 'This session is complete.',
          _ => 'Lobby updated.',
        },
      );
    }
  }

  @override
  Future<void> requestAppointment({
    required ClientProfile client,
    required String preferredWindow,
    required String note,
  }) async {
    final id = _id();
    _appointments[id] = AppointmentRequest(
      id: id,
      clientId: client.id,
      clientName: client.name,
      preferredWindow: preferredWindow,
      note: note,
      status: AppointmentStatus.requested,
      createdAt: DateTime.now(),
    );
    _pushAppointments();
    await sendMessage(
      threadId: client.threadId,
      senderId: 'system',
      senderName: 'Access Law Firm',
      senderRole: SenderRole.system,
      body: 'Appointment requested for $preferredWindow.',
    );
  }

  @override
  Stream<List<AppointmentRequest>> watchAppointments({String? clientId}) {
    scheduleMicrotask(_pushAppointments);
    if (clientId == null) return _appointmentsCtrl.stream;
    return _appointmentsCtrl.stream.map(
      (list) => list.where((a) => a.clientId == clientId).toList(),
    );
  }

  @override
  Future<void> setAppointmentStatus(String id, AppointmentStatus status) async {
    final current = _appointments[id];
    if (current == null) return;
    _appointments[id] = AppointmentRequest(
      id: current.id,
      clientId: current.clientId,
      clientName: current.clientName,
      preferredWindow: current.preferredWindow,
      note: current.note,
      status: status,
      createdAt: current.createdAt,
    );
    _pushAppointments();
  }

  @override
  Future<StaffProfile?> staffSignIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final normalized = email.trim().toLowerCase();
    if (_staffPasswords[normalized] != password) return null;
    return _staff.values.firstWhere((s) => s.email == normalized);
  }

  @override
  Stream<List<ClientProfile>> watchClients() {
    scheduleMicrotask(_pushClients);
    return _clientsCtrl.stream;
  }

  @override
  Stream<List<ActivationCode>> watchActivationCodes() {
    scheduleMicrotask(_pushCodes);
    return _codesCtrl.stream;
  }

  @override
  Future<ActivationCode> createActivationCode(String email) async {
    final code = _generateCode();
    final record = ActivationCode(
      code: code,
      email: email.trim().toLowerCase(),
      used: false,
      createdAt: DateTime.now(),
    );
    _codes[code] = record;
    _pushCodes();
    return record;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer('ALF-');
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[_rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  @override
  Future<void> saveZoomLinks({
    required String receptionZoomUrl,
    required String attorneyZoomUrl,
  }) async {
    _receptionZoomUrl = receptionZoomUrl;
    _attorneyZoomUrl = attorneyZoomUrl;
    for (final entry in _lobbies.entries) {
      _lobbies[entry.key] = entry.value.copyWith(
        receptionZoomUrl: receptionZoomUrl,
        attorneyZoomUrl: attorneyZoomUrl,
      );
      _pushLobby(entry.key);
    }
  }

  @override
  Future<Map<String, String>> loadZoomLinks() async => {
        'receptionZoomUrl': _receptionZoomUrl,
        'attorneyZoomUrl': _attorneyZoomUrl,
      };

  @override
  Future<void> registerPushToken(String ownerId, String token) async {}
}
