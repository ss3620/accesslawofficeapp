import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/client_models.dart';
import 'app_backend.dart';

/// Firebase-only chat + push used alongside the WordPress backend.
///
/// - Threads are keyed by the **WordPress client id** (same `threadId` the app
///   already uses).
/// - Clients sign in to Firebase **anonymously** and we store
///   `clients/{wpClientId}.firebaseUid` for Security Rules.
/// - Staff sign in to Firebase with **email/password** and must have a
///   `staff/{firebaseUid}` document (same as the pure Firebase backend).
class FirebaseChatService {
  FirebaseChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const clientsCollection = 'clients';
  static const threadsCollection = 'threads';
  static const staffCollection = 'staff';
  static const tokensCollection = 'device_tokens';

  bool _staffSession = false;

  /// Bind a WordPress client to an anonymous Firebase user for chat rules.
  Future<void> ensureClientSession({
    required String wpClientId,
    required String name,
    required String email,
  }) async {
    _staffSession = false;
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;

    await _db.collection(clientsCollection).doc(wpClientId).set({
      'name': name,
      'email': email,
      'threadId': wpClientId,
      'wpClientId': wpClientId,
      'firebaseUid': uid,
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection(threadsCollection).doc(wpClientId).set({
      'clientId': wpClientId,
      'clientName': name,
      'wpClientId': wpClientId,
      'participants': [wpClientId],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Staff must exist in Firebase Auth + `staff/{uid}` (see setup docs).
  Future<void> ensureStaffSession({
    required String email,
    required String password,
    required String displayName,
    required StaffRole role,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final snap = await _db.collection(staffCollection).doc(uid).get();
      if (!snap.exists) {
        // Auto-provision staff profile so WP-created receptionists can chat
        // after the Firebase Auth user is created with the same password.
        await _db.collection(staffCollection).doc(uid).set({
          'name': displayName,
          'email': email.trim().toLowerCase(),
          'role': role.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _staffSession = true;
    } on FirebaseAuthException catch (e) {
      throw BackendException(
        e.code == 'user-not-found' || e.code == 'invalid-credential'
            ? 'Chat login failed. Create this staff email in Firebase Authentication '
                'with the same password (see docs/FIREBASE_CHAT_PUSH.md).'
            : (e.message ?? 'Firebase staff sign-in failed.'),
      );
    }
  }

  Future<void> signOut() async {
    _staffSession = false;
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }

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

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String body,
    bool urgent = false,
  }) async {
    final threadRef = _db.collection(threadsCollection).doc(threadId);
    await threadRef.set({
      'clientId': threadId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastPreview': urgent ? 'Urgent request' : 'New message',
    }, SetOptions(merge: true));

    await threadRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'body': body,
      'urgent': urgent,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clients: token keyed by WP client id. Staff: keyed by Firebase uid
  /// (matches Cloud Function `staffIds()`).
  Future<void> registerPushToken(String ownerId, String token) async {
    final resolvedOwner = _staffSession
        ? (_auth.currentUser?.uid ?? ownerId)
        : ownerId;
    await _db.collection(tokensCollection).doc(token).set({
      'ownerId': resolvedOwner,
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
