import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the web build, read from compile-time defines so
/// that no project key is committed to the repository.
///
/// Fill in `config/firebase.json` (copy `config/firebase.example.json`) and
/// build with `--dart-define-from-file=config/firebase.json`. That file is
/// git-ignored. A web API key is not a secret in the cryptographic sense (every
/// visitor's browser receives it), but it belongs to one Firebase project and
/// should be restricted to your own site in the Google Cloud console.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  /// True when the build was given a project to talk to.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty && _messagingSenderId.isNotEmpty;

  static FirebaseOptions get web => const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain,
      );

  /// Used with the local emulators (`FIREBASE_EMULATOR_HOST`). The `demo-`
  /// prefix tells the emulators this is an offline project that can never touch
  /// a real one.
  static const FirebaseOptions emulator = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-honeyos',
  );
}
