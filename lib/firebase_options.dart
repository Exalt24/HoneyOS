// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
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
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDbjhOy1ajDq0p70iiYViPs7j4xMUF2EQ0',
    appId: '1:569652837811:web:0e768cf76e09f55a405fc6',
    messagingSenderId: '569652837811',
    projectId: 'honeyos',
    authDomain: 'honeyos.firebaseapp.com',
    storageBucket: 'honeyos.appspot.com',
    measurementId: 'G-EG39SH3ZZQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpRjQU3P1vam1BYcRtDZA1ldTYuYFl3Ok',
    appId: '1:569652837811:android:e95fc2a03a5be81e405fc6',
    messagingSenderId: '569652837811',
    projectId: 'honeyos',
    storageBucket: 'honeyos.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB3K4URfTkTRL7C9lGkZGRt92KX8yNSQCA',
    appId: '1:569652837811:ios:597abbea4ccd554a405fc6',
    messagingSenderId: '569652837811',
    projectId: 'honeyos',
    storageBucket: 'honeyos.appspot.com',
    iosBundleId: 'com.example.honeyOs',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB3K4URfTkTRL7C9lGkZGRt92KX8yNSQCA',
    appId: '1:569652837811:ios:a64488eb9641e473405fc6',
    messagingSenderId: '569652837811',
    projectId: 'honeyos',
    storageBucket: 'honeyos.appspot.com',
    iosBundleId: 'com.example.honeyOs.RunnerTests',
  );
}