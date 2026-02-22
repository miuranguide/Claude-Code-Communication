import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDXQSAs2LysCSI41kOFe9xdE8Ds8wqw9HQ',
    appId: '1:412000005447:web:80e1935d740c006cc47062',
    messagingSenderId: '412000005447',
    projectId: 'rakugaki-kikaku',
    storageBucket: 'rakugaki-kikaku.firebasestorage.app',
    authDomain: 'rakugaki-kikaku.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXQSAs2LysCSI41kOFe9xdE8Ds8wqw9HQ',
    appId: '1:412000005447:web:80e1935d740c006cc47062',
    messagingSenderId: '412000005447',
    projectId: 'rakugaki-kikaku',
    storageBucket: 'rakugaki-kikaku.firebasestorage.app',
  );
}
