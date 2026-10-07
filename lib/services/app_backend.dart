import '../models/client_models.dart';

/// Data source for the client MVP. Two implementations exist: Firestore for
/// production and an in-memory one so the app is demoable before the firm's
/// Firebase project is provisioned.
abstract class AppBackend {
  Future<void> initialize();

  /// True when messages/lobby updates arrive over a live connection.
  bool get isRemote;

  // —— Client activation ——

  Future<ClientProfile> redeemActivationCode({
    required String name,
    required String email,
    required String code,
  });

  Future<ClientProfile?> loadClient(String clientId);

  // —— Chat ——

  Stream<List<ChatMessage>> watchMessages(String threadId);

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String body,
    bool urgent = false,
  });

  // —— Video lobby ——

  Stream<LobbyState> watchLobby(String clientId);

  Future<void> enterLobby(ClientProfile client, {required String phone});

  Future<void> leaveLobby(String clientId);

  Future<void> setLobbyStatus(String clientId, LobbyStatus status);

  /// Full Virtual Lobby queue (website visitors + app clients checked in).
  Stream<LobbyQueueSnapshot> watchQueue();

  Future<void> setQueueAction({
    required int visitId,
    required String action,
    String? appClientId,
  });

  // —— Appointments ——

  Future<void> requestAppointment({
    required ClientProfile client,
    required String preferredWindow,
    required String note,
  });

  Stream<List<AppointmentRequest>> watchAppointments({String? clientId});

  Future<void> setAppointmentStatus(String id, AppointmentStatus status);

  // —— Staff ——

  Future<StaffProfile?> staffSignIn(String email, String password);

  /// Restores a previously signed-in staff member (token / Firebase user /
  /// saved email). Returns null if nobody is still signed in.
  Future<StaffProfile?> restoreStaffSession({String? savedEmail});

  Stream<List<ClientProfile>> watchClients();

  Stream<List<ActivationCode>> watchActivationCodes();

  Future<ActivationCode> createActivationCode(String email);

  Future<void> saveZoomLinks({
    required String receptionZoomUrl,
    required String attorneyZoomUrl,
  });

  Future<Map<String, String>> loadZoomLinks();

  // —— Push ——

  Future<void> registerPushToken(String ownerId, String token);
}

class BackendException implements Exception {
  BackendException(this.message);
  final String message;

  @override
  String toString() => message;
}
