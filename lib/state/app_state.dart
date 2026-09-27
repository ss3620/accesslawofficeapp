import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/client_models.dart';
import '../services/app_backend.dart';
import '../services/push_service.dart';
import '../services/session_storage.dart';
import '../services/wordpress_backend.dart';

enum SessionKind { none, client, staff }

class AppState extends ChangeNotifier {
  AppState({
    required this.backend,
    SessionStorage? storage,
  })  : storage = storage ?? SessionStorage(),
        push = PushService(backend);

  final AppBackend backend;
  final SessionStorage storage;
  final PushService push;

  bool bootstrapped = false;
  ClientProfile? client;
  StaffProfile? staff;
  String? lastError;
  StreamSubscription<LobbyQueueSnapshot>? _queueWatch;
  Set<String> _knownWaitingIds = {};
  bool _queueBaselineReady = false;

  SessionKind get sessionKind {
    if (client != null) return SessionKind.client;
    if (staff != null) return SessionKind.staff;
    return SessionKind.none;
  }

  bool get usesLiveBackend => backend.isRemote;

  Future<void> bootstrap() async {
    try {
      await backend.initialize();
      final savedId = await storage.getClientId();
      if (savedId != null) {
        final profile = await backend.loadClient(savedId);
        if (profile != null && profile.active) {
          client = profile;
          await push.start(profile.id);
        } else {
          await storage.clearClientId();
        }
      }
    } catch (error) {
      debugPrint('Bootstrap failed: $error');
      await storage.clearClientId();
    } finally {
      bootstrapped = true;
      notifyListeners();
    }
  }

  // —— Client ——

  Future<void> activate({
    required String name,
    required String email,
    required String code,
  }) async {
    lastError = null;
    try {
      final profile = await backend.redeemActivationCode(
        name: name,
        email: email,
        code: code,
      );
      client = profile;
      await storage.saveClientId(profile.id);
      await push.start(profile.id);
      notifyListeners();
    } on BackendException catch (e) {
      lastError = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      lastError = 'Could not activate. Check your connection and try again.';
      notifyListeners();
      throw BackendException(lastError!);
    }
  }

  Future<void> signOutClient() async {
    client = null;
    await storage.clearClientId();
    final b = backend;
    if (b is WordpressBackend) {
      await b.signOut();
    } else {
      await storage.clearAccessToken();
    }
    notifyListeners();
  }

  Stream<List<ChatMessage>> clientMessages() {
    final thread = client?.threadId;
    if (thread == null) return const Stream.empty();
    return backend.watchMessages(thread);
  }

  Stream<LobbyState> clientLobby() {
    final id = client?.id;
    if (id == null) return const Stream.empty();
    return backend.watchLobby(id);
  }

  Future<void> sendClientMessage(String body, {bool urgent = false}) async {
    final profile = client;
    if (profile == null || body.trim().isEmpty) return;
    await backend.sendMessage(
      threadId: profile.threadId,
      senderId: profile.id,
      senderName: profile.name,
      senderRole: SenderRole.client,
      body: body.trim(),
      urgent: urgent,
    );
  }

  Future<void> enterLobby() async {
    final profile = client;
    if (profile == null) return;
    await backend.enterLobby(profile);
  }

  Future<void> leaveLobby() async {
    final profile = client;
    if (profile == null) return;
    await backend.leaveLobby(profile.id);
  }

  Future<void> requestAppointment({
    required String preferredWindow,
    required String note,
  }) async {
    final profile = client;
    if (profile == null) return;
    await backend.requestAppointment(
      client: profile,
      preferredWindow: preferredWindow,
      note: note,
    );
  }

  Stream<List<AppointmentRequest>> clientAppointments() {
    final id = client?.id;
    if (id == null) return const Stream.empty();
    return backend.watchAppointments(clientId: id);
  }

  /// Emergency contact: posts an urgent, clearly flagged message the whole
  /// staff thread sees. Deliberately notification-only (no live tracking).
  Future<void> sendEmergencyAlert() async {
    final profile = client;
    if (profile == null) return;
    await backend.sendMessage(
      threadId: profile.threadId,
      senderId: profile.id,
      senderName: profile.name,
      senderRole: SenderRole.client,
      body:
          'URGENT: ${profile.name} may be detained and needs immediate contact.',
      urgent: true,
    );
  }

  // —— Staff ——

  Future<void> staffSignIn(String email, String password) async {
    lastError = null;
    try {
      final profile = await backend.staffSignIn(email, password);
      if (profile == null) {
        lastError = 'Invalid email or password.';
        notifyListeners();
        throw BackendException(lastError!);
      }
      staff = profile;
      await storage.saveStaffEmail(profile.email);
      await push.start(profile.id);
      _startStaffQueueWatch();
      notifyListeners();
    } on BackendException catch (e) {
      lastError = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> staffSignOut() async {
    await _stopStaffQueueWatch();
    staff = null;
    await storage.clearStaffEmail();
    final b = backend;
    if (b is WordpressBackend) {
      await b.signOut();
    } else {
      await storage.clearAccessToken();
    }
    notifyListeners();
  }

  void _startStaffQueueWatch() {
    _queueWatch?.cancel();
    _knownWaitingIds = {};
    _queueBaselineReady = false;
    _queueWatch = backend.watchQueue().listen((snapshot) {
      final waitingIds = snapshot.items
          .where((v) => v.status == QueueVisitStatus.waiting)
          .map((v) => v.id.toString())
          .toSet();
      if (!_queueBaselineReady) {
        _knownWaitingIds = waitingIds;
        _queueBaselineReady = true;
        return;
      }
      final newcomers = waitingIds.difference(_knownWaitingIds);
      _knownWaitingIds = waitingIds;
      if (newcomers.isNotEmpty) {
        push.showLobbyWaitingAlert();
      }
    }, onError: (Object error) {
      debugPrint('Staff queue watch failed: $error');
    });
  }

  Future<void> _stopStaffQueueWatch() async {
    await _queueWatch?.cancel();
    _queueWatch = null;
    _knownWaitingIds = {};
    _queueBaselineReady = false;
  }

  Stream<List<ClientProfile>> staffClients() => backend.watchClients();

  Stream<List<ActivationCode>> staffCodes() => backend.watchActivationCodes();

  Stream<List<AppointmentRequest>> staffAppointments() =>
      backend.watchAppointments();

  Stream<LobbyState> lobbyFor(String clientId) => backend.watchLobby(clientId);

  Stream<List<ChatMessage>> threadFor(String threadId) =>
      backend.watchMessages(threadId);

  Future<void> sendStaffMessage(String threadId, String body) async {
    final profile = staff;
    if (profile == null || body.trim().isEmpty) return;
    await backend.sendMessage(
      threadId: threadId,
      senderId: profile.id,
      senderName: profile.name,
      senderRole: profile.role.senderRole,
      body: body.trim(),
    );
  }

  Future<void> setLobbyStatus(String clientId, LobbyStatus status) =>
      backend.setLobbyStatus(clientId, status);

  Stream<LobbyQueueSnapshot> staffQueue() => backend.watchQueue();

  Future<void> setQueueAction(QueueVisit visit, String action) =>
      backend.setQueueAction(
        visitId: visit.id,
        action: action,
        appClientId: visit.appClientId,
      );

  Future<ActivationCode> createActivationCode(String email) =>
      backend.createActivationCode(email);

  Future<Map<String, String>> loadZoomLinks() => backend.loadZoomLinks();

  Future<void> saveZoomLinks({
    required String receptionZoomUrl,
    required String attorneyZoomUrl,
  }) =>
      backend.saveZoomLinks(
        receptionZoomUrl: receptionZoomUrl,
        attorneyZoomUrl: attorneyZoomUrl,
      );

  Future<void> setAppointmentStatus(String id, AppointmentStatus status) =>
      backend.setAppointmentStatus(id, status);
}
