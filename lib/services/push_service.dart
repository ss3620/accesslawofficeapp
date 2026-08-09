import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_backend.dart';

/// FCM registration. Notification bodies are intentionally generic — no case
/// details ever leave in a push payload.
class PushService {
  PushService(this._backend);

  final AppBackend _backend;
  bool _started = false;

  Future<void> start(String ownerId) async {
    if (!_backend.isRemote || _started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await _backend.registerPushToken(ownerId, token);
      }
      messaging.onTokenRefresh.listen((refreshed) {
        _backend.registerPushToken(ownerId, refreshed);
      });
    } catch (error) {
      debugPrint('Push registration skipped: $error');
      _started = false;
    }
  }
}
