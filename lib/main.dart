import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/app_backend.dart';
import 'services/firebase_backend.dart';
import 'services/firebase_chat_service.dart';
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

/// WordPress for lobby/auth when configured.
/// Firebase for chat + push when configured (alongside WP, or alone).
Future<AppBackend> _createBackend() async {
  final firebaseOk = await _tryInitFirebase();

  if (useWordpressBackend) {
    debugPrint('Using WordPress backend at ${WpConfig.apiRoot}');
    if (firebaseOk) {
      debugPrint('Firebase chat + push enabled.');
      return WordpressBackend(chat: FirebaseChatService());
    }
    debugPrint(
      'Firebase not configured — chat falls back to WordPress polling (no push).',
    );
    return WordpressBackend();
  }

  if (!firebaseOk) {
    debugPrint('Firebase not configured — using the local demo backend.');
    return LocalBackend();
  }
  return FirebaseBackend();
}

Future<bool> _tryInitFirebase() async {
  if (!isFirebaseConfigured) return false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    return true;
  } catch (error) {
    debugPrint('Firebase init failed ($error)');
    return false;
  }
}
