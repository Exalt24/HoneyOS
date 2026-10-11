import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:honey_os/UI/loadingscreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Optional: build with --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 to talk to
// the local Firebase emulators instead of the hosted project. The ports default
// to the emulator defaults (Firestore 8080, Storage 9199) and can be overridden
// with FIRESTORE_EMULATOR_PORT and STORAGE_EMULATOR_PORT. With no defines the
// app behaves exactly as before.
const String _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const int _firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const int _storageEmulatorPort = int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

Future<void> main() async {


  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyDbjhOy1ajDq0p70iiYViPs7j4xMUF2EQ0",
            authDomain: "honeyos.firebaseapp.com",
            projectId: "honeyos",
            storageBucket: "honeyos.appspot.com",
            messagingSenderId: "569652837811",
            appId: "1:569652837811:web:0e768cf76e09f55a405fc6",
            measurementId: "G-EG39SH3ZZQ"
        )
    );
    print('Firebase initialized');
  } else {
    await Firebase.initializeApp();
  }
  if (_emulatorHost.isNotEmpty) {
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storageEmulatorPort);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return  const MaterialApp(
      title: 'Honey OS',
      home: LoadingScreen(),
    );
  }
}