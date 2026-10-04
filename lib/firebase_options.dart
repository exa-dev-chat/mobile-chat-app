// File generated for FlutterFire initialization.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDBmRqNotWO-U6sypr-Rtj5caaFwycfX2I',
    appId: '1:1043117609248:android:5f4ef11b63e9c03ffb8745',
    messagingSenderId: '1043117609248',
    projectId: 'testflutterfirebase-26e7c',
    storageBucket: 'testflutterfirebase-26e7c.firebasestorage.app',
    databaseURL: 'https://testflutterfirebase-26e7c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAnB0fURv42YuQWnK5rXAEll3w9D3sPXns',
    appId: '1:1043117609248:ios:daa7f61a20cd2adcfb8745',
    messagingSenderId: '1043117609248',
    projectId: 'testflutterfirebase-26e7c',
    storageBucket: 'testflutterfirebase-26e7c.firebasestorage.app',
    iosBundleId: 'cloud.eka-dev.chat-app',
    databaseURL: 'https://testflutterfirebase-26e7c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
