import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_backend.dart';

const _channelId = 'alf_messages';
const _lobbyChannelId = 'alf_lobby';

/// Called when the user opens the app from a notification.
typedef PushOpenHandler = void Function({String? type, String? threadId});

/// FCM registration + display. Bodies stay generic — no case details.
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
    if (!_backend.isRemote) return;
    _ownerId = ownerId;
    try {
      await _ensureLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
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
        _channelId,
        'Messages',
        description: 'Chat and lobby alerts',
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
    _localReady = true;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final type = message.data['type'];
    final isLobbyWaiting = type == 'lobby_waiting';
    final title = message.notification?.title ?? 'Access Law Firm';
    final body = message.notification?.body ??
        (isLobbyWaiting
            ? 'Someone is waiting in the Virtual Lobby.'
            : 'You have a new message.');
    final channel = isLobbyWaiting ? _lobbyChannelId : _channelId;
    final channelName = isLobbyWaiting ? 'Virtual Lobby' : 'Messages';

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          channelDescription: isLobbyWaiting
              ? 'Someone waiting in the Virtual Lobby'
              : 'Chat and lobby alerts',
          importance: isLobbyWaiting ? Importance.max : Importance.high,
          priority: isLobbyWaiting ? Priority.max : Priority.high,
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
      payload: _payloadFrom(message.data),
    );
  }

  /// Local alert when staff queue polling sees a new waiting visitor.
  Future<void> showLobbyWaitingAlert() async {
    try {
      await _ensureLocalNotifications();
      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Access Law Firm',
        'Someone is waiting in the Virtual Lobby.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _lobbyChannelId,
            'Virtual Lobby',
            channelDescription: 'Someone waiting in the Virtual Lobby',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
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
