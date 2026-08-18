import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_backend.dart';

const _channelId = 'alf_messages';

/// FCM registration + display. Bodies stay generic — no case details.
class PushService {
  PushService(this._backend);

  final AppBackend _backend;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _started = false;
  bool _localReady = false;

  Future<void> start(String ownerId) async {
    if (!_backend.isRemote) return;
    try {
      await _ensureLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        await _backend.registerPushToken(ownerId, token);
      }
      if (!_started) {
        messaging.onTokenRefresh.listen((refreshed) {
          _backend.registerPushToken(ownerId, refreshed);
        });
        FirebaseMessaging.onMessage.listen(_showForeground);
      }
      _started = true;
    } catch (error) {
      debugPrint('Push registration skipped: $error');
      _started = false;
    }
  }

  Future<void> _ensureLocalNotifications() async {
    if (_localReady) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(init);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Messages',
            description: 'Chat and lobby alerts',
            importance: Importance.high,
          ),
        );
    _localReady = true;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Access Law Firm';
    final body = message.notification?.body ?? 'You have a new message.';
    await _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Messages',
          channelDescription: 'Chat and lobby alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
