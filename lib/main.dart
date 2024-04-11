import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:honey_os/UI/loadingscreen.dart';
import 'package:firebase_core/firebase_core.dart';

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