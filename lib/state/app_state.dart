import 'package:flutter/foundation.dart';

import '../models/client_models.dart';
import '../services/app_backend.dart';
import '../services/firebase_backend.dart';
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
  final Map<String, int> unreadByThread = {};
  final Map<String, DateTime> _lastReadCache = {};

  SessionKind get sessionKind {
    if (client != null) return SessionKind.client;
    if (staff != null) return SessionKind.staff;
    return SessionKind.none;
  }

  bool get usesLiveBackend => backend.isRemote;

  int unreadCountFor(String threadId) => unreadByThread[threadId] ?? 0;

  int get totalClientUnread =>
      unreadByThread.values.fold(0, (sum, count) => sum + count);

  static int countUnreadClientMessages(
    List<ChatMessage> messages,
    DateTime? lastRead,
  ) {
    return messages.where((message) {
      if (message.senderRole != SenderRole.client) return false;
      if (lastRead == null) return true;
      return message.createdAt.isAfter(lastRead);
    }).length;
  }

  Future<void> updateUnreadForThread(
    String threadId,
    List<ChatMessage> messages,
  ) async {
    final lastRead =
        _lastReadCache[threadId] ?? await storage.getStaffLastRead(threadId);
    if (lastRead != null) _lastReadCache[threadId] = lastRead;
    final count = countUnreadClientMessages(messages, lastRead);
    if (unreadByThread[threadId] == count) return;
    unreadByThread[threadId] = count;
    notifyListeners();
  }

  Future<void> markThreadRead(
    String threadId, {
    List<ChatMessage>? messages,
  }) async {
    var stamp = DateTime.now();
    if (messages != null && messages.isNotEmpty) {
      final latest = messages
          .map((message) => message.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      if (latest.isAfter(stamp)) stamp = latest;
      stamp = stamp.add(const Duration(milliseconds: 500));
    }
    _lastReadCache[threadId] = stamp;
    await storage.setStaffLastRead(threadId, stamp);
    if (unreadByThread[threadId] == 0) return;
    unreadByThread[threadId] = 0;
    notifyListeners();
  }

  void clearUnread(String threadId) {
    if (!unreadByThread.containsKey(threadId)) return;
    unreadByThread.remove(threadId);
    notifyListeners();
  }

  Future<void> bootstrap() async {
    try {
      await backend.initialize();
      await _restoreClient();
      if (client == null) {
        await _restoreStaff();
      }
    } catch (error) {
      debugPrint('Bootstrap failed: $error');
    } finally {
      bootstrapped = true;
      notifyListeners();
    }
  }

  Future<void> _restoreClient() async {
    final savedId = await storage.getClientId();
    if (savedId == null) return;
    try {
      final profile = await backend.loadClient(savedId);
      if (profile != null && profile.active) {
        client = profile;
        await push.start(profile.id);
      } else {
        await storage.clearClientId();
      }
    } catch (error) {
      debugPrint('Client restore failed: $error');
    }
  }

  Future<void> _restoreStaff() async {
    try {
      final restored = await backend.restoreStaffSession(
        savedEmail: await storage.getStaffEmail(),
      );
      if (restored == null) return;
      staff = restored;
      await storage.saveStaffEmail(restored.email);
      await storage.saveStaffProfile(restored);
      await push.start(restored.id);
    } catch (error) {
      debugPrint('Staff restore failed: $error');
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
      staff = null;
      await storage.saveClientId(profile.id);
      await storage.clearStaffEmail();
      await storage.clearStaffProfile();
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
      try {
        await storage.saveStaffEmail(profile.email);
        await storage.saveStaffProfile(profile);
      } catch (error) {
        debugPrint('Could not persist staff session: $error');
      }
      await push.start(profile.id);
      notifyListeners();
    } on BackendException catch (e) {
      lastError = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> staffSignOut() async {
    staff = null;
    unreadByThread.clear();
    _lastReadCache.clear();
    await storage.clearStaffSession();
    final b = backend;
    if (b is WordpressBackend) {
      await b.signOut();
    } else if (b is FirebaseBackend) {
      await b.signOut();
    }
    notifyListeners();
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
