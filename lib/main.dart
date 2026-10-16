import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:honey_os/UI/loadingscreen.dart';
import 'package:honey_os/firebase_options.dart';

// Optional: build with --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 to talk to
// the local Firebase emulators instead of a hosted project. The ports default to
// the ones in emulator/firebase.json (Firestore 8080, Auth 9099) and can be
// overridden with FIRESTORE_EMULATOR_PORT and AUTH_EMULATOR_PORT.
const String _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const int _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const int _authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool useEmulator = _emulatorHost.isNotEmpty;
  if (!useEmulator && !DefaultFirebaseOptions.isConfigured) {
    runApp(const SetupNeededApp());
    return;
  }

  await Firebase.initializeApp(
    options: useEmulator ? DefaultFirebaseOptions.emulator : DefaultFirebaseOptions.web,
  );
  if (useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authEmulatorPort);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Honey OS',
      home: LoadingScreen(),
    );
  }
}

/// Shown instead of the app when the build has no Firebase project, so a fresh
/// clone explains itself rather than failing with a blank page.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Honey OS',
      home: Scaffold(
        backgroundColor: Color.fromARGB(255, 237, 140, 0),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'HoneyOS has no Firebase project to talk to.\n\n'
              'Copy config/firebase.example.json to config/firebase.json, fill in '
              'your project, and build with --dart-define-from-file=config/firebase.json '
              '(see the README).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
