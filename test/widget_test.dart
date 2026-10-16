import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_os/UI/loadingscreen.dart';
import 'package:honey_os/firebase_options.dart';
import 'package:honey_os/main.dart';

void main() {
  testWidgets('a build without a Firebase project explains how to configure one', (WidgetTester tester) async {
    // Tests run without --dart-define-from-file, so nothing is configured.
    expect(DefaultFirebaseOptions.isConfigured, isFalse);

    await tester.pumpWidget(const SetupNeededApp());

    expect(find.textContaining('no Firebase project'), findsOneWidget);
    expect(find.textContaining('config/firebase.json'), findsOneWidget);
  });

  testWidgets('the boot screen shows the bee animation', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingScreen()));

    expect(find.byType(Image), findsOneWidget);

    // Replace the screen so its 3 second timer fires after it is unmounted and
    // never tries to open the user picker (which needs a live Firebase).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
