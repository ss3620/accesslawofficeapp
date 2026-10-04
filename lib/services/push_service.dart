import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_backend.dart';

const _messageChannelId = 'alf_messages';
const _lobbyChannelId = 'alf_lobby';
const _appointmentChannelId = 'alf_appointments';

/// Called when the user opens the app from a notification.
typedef PushOpenHandler = void Function({String? type, String? threadId});

enum AlertKind { message, appointment, lobby }

/// FCM registration + local banners. Bodies stay generic — no case notes.
class PushService {
  PushService(this._backend);

  final AppBackend _backend;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _started = false;
  bool _localReady = false;
  String? _ownerId;

  /// Set by the app shell to navigate on notification tap.
  PushOpenHandler? onOpened;

  Future<void> start(String ownerId) async {
    if (!_backend.isRemote) {
      await _ensureLocalNotifications();
      return;
    }
    _ownerId = ownerId;
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
          final id = _ownerId;
          if (id != null) {
            _backend.registerPushToken(id, refreshed);
          }
        });
        FirebaseMessaging.onMessage.listen(_showForeground);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteOpen);
      }
      _started = true;

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleRemoteOpen(initial);
      }
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
    String? payload,
  }) async {
    await _ensureLocalNotifications();
    final channelId = switch (kind) {
      AlertKind.lobby => _lobbyChannelId,
      AlertKind.appointment => _appointmentChannelId,
      AlertKind.message => _messageChannelId,
    };
    final channelName = switch (kind) {
      AlertKind.lobby => 'Virtual Lobby',
      AlertKind.appointment => 'Appointments',
      AlertKind.message => 'Messages',
    };
    final description = switch (kind) {
      AlertKind.lobby => 'Someone waiting in the Virtual Lobby',
      AlertKind.appointment => 'Appointment requests and updates',
      AlertKind.message => 'New client messages',
    };
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: description,
          importance: kind == AlertKind.lobby ? Importance.max : Importance.high,
          priority: kind == AlertKind.lobby ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
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
    await _local.initialize(
      init,
      onDidReceiveNotificationResponse: _handleLocalOpen,
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
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
        _lobbyChannelId,
        'Virtual Lobby',
        description: 'Someone waiting in the Virtual Lobby',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
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
    final type = message.data['type']?.toString();
    final title = message.notification?.title ?? 'Access Law Firm';
    final kind = switch (type) {
      'lobby_waiting' => AlertKind.lobby,
      'appointment' => AlertKind.appointment,
      _ => AlertKind.message,
    };
    final body = message.notification?.body ??
        switch (kind) {
          AlertKind.lobby => 'Someone is waiting in the Virtual Lobby.',
          AlertKind.appointment => 'You have an appointment update.',
          AlertKind.message => 'You have a new message.',
        };
    await showAlert(
      kind: kind,
      title: title,
      body: body,
      payload: _payloadFrom(message.data),
    );
  }

  /// Local alert when staff queue polling sees a new waiting visitor.
  Future<void> showLobbyWaitingAlert() async {
    try {
      await showAlert(
        kind: AlertKind.lobby,
        title: 'Access Law Firm',
        body: 'Someone is waiting in the Virtual Lobby.',
        payload: 'type=lobby_waiting',
      );
    } catch (error) {
      debugPrint('Lobby waiting alert skipped: $error');
    }
  }

  void _handleRemoteOpen(RemoteMessage message) {
    onOpened?.call(
      type: message.data['type'],
      threadId: message.data['threadId'],
    );
  }

  void _handleLocalOpen(NotificationResponse response) {
    final parsed = _parsePayload(response.payload);
    onOpened?.call(
      type: parsed['type'],
      threadId: parsed['threadId'],
    );
  }

  String _payloadFrom(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final threadId = data['threadId']?.toString() ?? '';
    return 'type=$type&threadId=$threadId';
  }

  Map<String, String?> _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const {'type': null, 'threadId': null};
    }
    final out = <String, String?>{};
    for (final part in payload.split('&')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      out[part.substring(0, i)] = part.substring(i + 1);
    }
    return {
      'type': out['type'],
      'threadId': out['threadId'],
    };
  }
}
