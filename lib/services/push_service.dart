import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_backend.dart';

const _messageChannelId = 'alf_messages';
const _appointmentChannelId = 'alf_appointments';

enum AlertKind { message, appointment }

/// FCM registration + local banners. Bodies stay generic — no case notes.
class PushService {
  PushService(this._backend);

  final AppBackend _backend;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _started = false;
  bool _localReady = false;

  Future<void> start(String ownerId) async {
    if (!_backend.isRemote) {
      await _ensureLocalNotifications();
      return;
    }
    try {
      await _ensureLocalNotifications();
      await requestPermission();
      final messaging = FirebaseMessaging.instance;
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

  Future<bool> requestPermission() async {
    try {
      await _ensureLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final localOk = await _local
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          true;
      return localOk &&
          (settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional);
    } catch (error) {
      debugPrint('Notification permission skipped: $error');
      return false;
    }
  }

  Future<void> showAlert({
    required AlertKind kind,
    required String title,
    required String body,
  }) async {
    await _ensureLocalNotifications();
    final channelId = kind == AlertKind.message
        ? _messageChannelId
        : _appointmentChannelId;
    final channelName =
        kind == AlertKind.message ? 'Messages' : 'Appointments';
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: kind == AlertKind.message
              ? 'New client messages'
              : 'Appointment requests and updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _ensureLocalNotifications() async {
    if (_localReady) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _local.initialize(init);
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _messageChannelId,
        'Messages',
        description: 'New client messages',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _appointmentChannelId,
        'Appointments',
        description: 'Appointment requests and updates',
        importance: Importance.high,
      ),
    );
    _localReady = true;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Access Law Firm';
    final body = message.notification?.body ?? 'You have a new update.';
    final kind = (message.data['type'] == 'appointment')
        ? AlertKind.appointment
        : AlertKind.message;
    await showAlert(kind: kind, title: title, body: body);
  }
}
