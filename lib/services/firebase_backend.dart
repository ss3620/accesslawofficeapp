import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/client_models.dart';
import 'app_backend.dart';

/// Production backend: Firestore for data, Firebase Auth for identity.
///
/// Clients never sign in with a password. They redeem a one-time activation
/// code issued after payment, which binds an anonymous Firebase uid to a
/// `clients/{uid}` document. Security Rules key off that document.
class FirebaseBackend implements AppBackend {
  FirebaseBackend({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const clientsCollection = 'clients';
  static const codesCollection = 'activation_codes';
  static const threadsCollection = 'threads';
  static const lobbyCollection = 'lobby';
  static const appointmentsCollection = 'appointment_requests';
  static const staffCollection = 'staff';
  static const configDoc = 'config/app';

  @override
  bool get isRemote => true;

  @override
  Future<void> initialize() async {}

  // —— Client activation ——

  @override
  Future<ClientProfile> redeemActivationCode({
    required String name,
    required String email,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    final normalizedEmail = email.trim().toLowerCase();
    final codeRef = _db.collection(codesCollection).doc(normalizedCode);
    final codeSnap = await codeRef.get();

    if (!codeSnap.exists) {
      throw BackendException('That activation code was not recognized.');
    }
    final codeData = codeSnap.data()!;
    final issuedTo = ((codeData['email'] ?? '') as String).toLowerCase();
    if (issuedTo.isNotEmpty && issuedTo != normalizedEmail) {
      throw BackendException('This code was issued to a different email.');
    }

    final credential = _auth.currentUser != null
        ? null
        : await _auth.signInAnonymously();
    final uid = _auth.currentUser?.uid ?? credential!.user!.uid;

    final alreadyUsedBy = codeData['clientId'] as String?;
    if ((codeData['used'] ?? false) == true && alreadyUsedBy != uid) {
      throw BackendException('That activation code has already been used.');
    }

    final clientRef = _db.collection(clientsCollection).doc(uid);
    await clientRef.set({
      'name': name.trim(),
      'email': normalizedEmail,
      'threadId': uid,
      'active': true,
      'activationCode': normalizedCode,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await codeRef.set({
      'used': true,
      'clientId': uid,
      'email': normalizedEmail,
      'redeemedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection(threadsCollection).doc(uid).set({
      'clientId': uid,
      'clientName': name.trim(),
      'participants': [uid],
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final zoom = await loadZoomLinks();
    await _db.collection(lobbyCollection).doc(uid).set({
      'status': LobbyStatus.idle.name,
      'clientName': name.trim(),
      'receptionZoomUrl': zoom['receptionZoomUrl'] ?? '',
      'attorneyZoomUrl': zoom['attorneyZoomUrl'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final saved = await clientRef.get();
    return ClientProfile.fromMap(uid, saved.data() ?? {});
  }

  @override
  Future<ClientProfile?> loadClient(String clientId) async {
    final snap = await _db.collection(clientsCollection).doc(clientId).get();
    if (!snap.exists) return null;
    final profile = ClientProfile.fromMap(clientId, snap.data()!);
    if (!profile.active) return null;
    return profile;
  }

  // —— Chat ——

  @override
  Stream<List<ChatMessage>> watchMessages(String threadId) {
    return _db
        .collection(threadsCollection)
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessage.fromMap(d.id, d.data()))
              .toList(),
        );
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
    final threadRef = _db.collection(threadsCollection).doc(threadId);
    await threadRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'body': body,
      'urgent': urgent,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await threadRef.set({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastPreview': urgent ? 'Urgent request' : 'New message',
    }, SetOptions(merge: true));
  }

  // —— Video lobby ——

  @override
  Stream<LobbyState> watchLobby(String clientId) {
    return _db.collection(lobbyCollection).doc(clientId).snapshots().map(
          (snap) => snap.exists
              ? LobbyState.fromMap(clientId, snap.data()!)
              : LobbyState.empty(clientId),
        );
  }

  @override
  Future<void> enterLobby(ClientProfile client) async {
    final zoom = await loadZoomLinks();
    await _db.collection(lobbyCollection).doc(client.id).set({
      'status': LobbyStatus.waiting.name,
      'clientName': client.name,
      'receptionZoomUrl': zoom['receptionZoomUrl'] ?? '',
      'attorneyZoomUrl': zoom['attorneyZoomUrl'] ?? '',
      'enteredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    await _db.collection(lobbyCollection).doc(clientId).set({
      'status': LobbyStatus.idle.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setLobbyStatus(String clientId, LobbyStatus status) async {
    await _db.collection(lobbyCollection).doc(clientId).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (status == LobbyStatus.idle) return;
    final client = await loadClient(clientId);
    if (client == null) return;
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

  @override
  Stream<LobbyQueueSnapshot> watchQueue() =>
      Stream.value(LobbyQueueSnapshot.empty());

  @override
  Future<void> setQueueAction({
    required int visitId,
    required String action,
    String? appClientId,
  }) async {}

  // —— Appointments ——

  @override
  Future<void> requestAppointment({
    required ClientProfile client,
    required String preferredWindow,
    required String note,
  }) async {
    await _db.collection(appointmentsCollection).add({
      'clientId': client.id,
      'clientName': client.name,
      'preferredWindow': preferredWindow,
      'note': note,
      'status': AppointmentStatus.requested.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    Query<Map<String, dynamic>> query =
        _db.collection(appointmentsCollection).orderBy('createdAt', descending: true);
    if (clientId != null) {
      query = _db
          .collection(appointmentsCollection)
          .where('clientId', isEqualTo: clientId);
    }
    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => AppointmentRequest.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<void> setAppointmentStatus(String id, AppointmentStatus status) async {
    await _db.collection(appointmentsCollection).doc(id).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // —— Staff ——

  @override
  Future<StaffProfile?> staffSignIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final snap = await _db.collection(staffCollection).doc(uid).get();
      if (!snap.exists) {
        await _auth.signOut();
        throw BackendException('This account is not authorized for staff use.');
      }
      return StaffProfile.fromMap(uid, snap.data()!);
    } on FirebaseAuthException catch (e) {
      throw BackendException(e.message ?? 'Sign in failed.');
    }
  }

  @override
  Future<StaffProfile?> restoreStaffSession({String? savedEmail}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _db.collection(staffCollection).doc(user.uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return StaffProfile.fromMap(user.uid, snap.data()!);
  }

  Future<void> signOut() => _auth.signOut();

  @override
  Stream<List<ClientProfile>> watchClients() {
    return _db
        .collection(clientsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ClientProfile.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<ActivationCode>> watchActivationCodes() {
    return _db
        .collection(codesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ActivationCode.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<ActivationCode> createActivationCode(String email) async {
    final code = _generateCode();
    final record = {
      'email': email.trim().toLowerCase(),
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection(codesCollection).doc(code).set(record);
    return ActivationCode(
      code: code,
      email: email.trim().toLowerCase(),
      used: false,
      createdAt: DateTime.now(),
    );
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer('ALF-');
    var seed = now;
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[seed % chars.length]);
      seed = seed ~/ chars.length + i * 7;
    }
    return buffer.toString();
  }

  @override
  Future<void> saveZoomLinks({
    required String receptionZoomUrl,
    required String attorneyZoomUrl,
  }) async {
    await _db.doc(configDoc).set({
      'receptionZoomUrl': receptionZoomUrl,
      'attorneyZoomUrl': attorneyZoomUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, String>> loadZoomLinks() async {
    final snap = await _db.doc(configDoc).get();
    final data = snap.data() ?? {};
    return {
      'receptionZoomUrl': (data['receptionZoomUrl'] ?? '') as String,
      'attorneyZoomUrl': (data['attorneyZoomUrl'] ?? '') as String,
    };
  }

  // —— Push ——

  @override
  Future<void> registerPushToken(String ownerId, String token) async {
    await _db.collection('device_tokens').doc(token).set({
      'ownerId': ownerId,
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
