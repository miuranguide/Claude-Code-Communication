import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXQSAs2LysCSI41kOFe9xdE8Ds8wqw9HQ',
    appId: '1:412000005447:android:e86260a8cc0967fdc47062',
    messagingSenderId: '412000005447',
    projectId: 'rakugaki-kikaku',
    storageBucket: 'rakugaki-kikaku.firebasestorage.app',
  );
}
