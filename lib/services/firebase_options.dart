// File generated for Firebase project access-law-firm.
// Android + iOS apps configured via Firebase CLI (flutterfire configure
// fails on this Windows PATH setup, so options were written manually).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

const String kPlaceholderMarker = 'REPLACE_ME';

bool get isFirebaseConfigured =>
    !DefaultFirebaseOptions.currentPlatform.apiKey.contains(kPlaceholderMarker);

abstract final class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBxZGyUdh7Zy2wXGtza6CWayxxGb-R03yA',
    appId: '1:205875883184:android:d65b93cdb51778d2d45f75',
    messagingSenderId: '205875883184',
    projectId: 'access-law-firm',
    storageBucket: 'access-law-firm.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAbdhuC_EMBg9zIaQNG2GJYt4nqwcpwyA',
    appId: '1:205875883184:ios:9d1c0fe9d252b7e8d45f75',
    messagingSenderId: '205875883184',
    projectId: 'access-law-firm',
    storageBucket: 'access-law-firm.firebasestorage.app',
    iosBundleId: 'com.accesslawoffice.accessLawOffice',
  );
}
