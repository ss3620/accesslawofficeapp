import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/app_backend.dart';
import 'services/firebase_backend.dart';
import 'services/firebase_options.dart';
import 'services/local_backend.dart';
import 'services/wordpress_backend.dart';
import 'services/wp_config.dart';
import 'state/app_state.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Bodies are generic by design; nothing sensitive to process here.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await _createBackend();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(backend: backend),
      child: const AccessLawApp(),
    ),
  );
}

/// Prefer WordPress when configured; otherwise Firebase; otherwise local demo.
Future<AppBackend> _createBackend() async {
  if (useWordpressBackend) {
    debugPrint('Using WordPress backend at ${WpConfig.apiRoot}');
    return WordpressBackend();
  }

  if (!isFirebaseConfigured) {
    debugPrint('Firebase not configured — using the local demo backend.');
    return LocalBackend();
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    return FirebaseBackend();
  } catch (error) {
    debugPrint('Firebase init failed ($error) — falling back to local backend.');
    return LocalBackend();
  }
}
