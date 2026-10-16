# HoneyOS

![HoneyOS running on a local stack: boot animation, register a user, log in, ask Honey for the date by voice, then create a folder and a text file that persist](docs/demo.gif)

*Recorded from the real app on one machine: a Flutter web build against local Firebase emulators, with the microphone stubbed (two spoken commands are injected). Nothing is deployed anywhere.*

A desktop operating-system simulation built with Flutter for a university project. It boots into a hexagon user picker, logs users in, and gives each of them a small file system, and the whole thing can be driven by voice: you say "Honey, tell me the date, please" and the assistant answers.

## What it does

- **Boot and user picker.** A bee boot animation (about 3 seconds), then a honeycomb of up to 10 user slots. An empty slot is a "+" that opens registration.
- **Register and log in.** A username and a password, each capped at 10 characters, plus a profile picture (a default one, or a photo you pick, uploaded to Firebase Storage). Logging in is a password field or a spoken "Honey, the password is ..., please".
- **Home screen.** A clock and greeting, with six tiles: Tell me about Honey, Open a File, Create a File, Tell me the Date, View Files and Buzz Out.
- **Voice control.** Speech recognition (`speech_to_text`) and spoken replies (`flutter_tts`). A command has to start with "honey" and end with "please". The home screen understands create a file, view files, open a file, tell me about honey, tell me the date, go back, buzz out and help. The editor adds save, save as, undo the changes, redo the changes, clear all, write the following, read the text, name it and go home.
- **File system.** View Files shows the disks ("Local Disk C"), and inside a disk you can create folders and text files, open a file, and edit it in a small editor with Save, Save As, Undo and Redo. Folders and files are stored in Cloud Firestore and belong to the user who made them. Rename and delete are in the code (`lib/UI/file.dart`) but I did not drive them in the recording.

## What I ran

On 11 Oct 2026, Flutter 3.47.7 (Dart 3.13.5), Chromium, the Firebase emulators for Firestore and Storage:

1. Registered a user with the default picture.
2. Logged in with the typed password.
3. Said "honey tell me the date please" and got the date dialog, then "honey go back please" to close it.
4. Created a folder `HiveNotes` on disk C, created a file in it, typed a line, saved, reopened it and saw the line again.

The microphone part is simulated: headless Chromium has no speech engine, so the recording script replaces the browser's `SpeechRecognition` object with a stub and feeds it those two phrases. Everything else in the clip is real clicks and typing against the real app. A real microphone path was not exercised.

## Run it locally

You need the Flutter SDK, Node 18 or newer, JDK 21 or newer (for the emulators) and Chrome or Edge. This is the setup the recording used, with no hosted Firebase involved.

```bash
# 1. Start the Firebase emulators (Firestore on 8080, Storage on 9199)
npx firebase-tools emulators:start --only firestore,storage --project honeyos --config emulator/firebase.json

# 2. In a second terminal: add the disk and the default profile picture the app expects
node emulator/seed.mjs

# 3. Build the web app pointed at the emulators and serve it
flutter pub get
flutter build web --release --no-web-resources-cdn --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
cd build/web && python -m http.server 8000
```

Then open http://localhost:8000 in Chrome or Edge and allow the microphone when asked.

- The emulator rules in `emulator/` are wide open on purpose; they are for local use only.
- Without `FIREBASE_EMULATOR_HOST` the app behaves as it always did and talks to the Firebase project in `lib/main.dart` and `lib/firebase_options.dart`, which is the author's own `honeyos` project. There is no hosted copy, and I did not check that project is still alive.
- For the recording the emulators ran on ports 4901 and 4902 because the defaults were taken on my machine, so I built with `--dart-define=FIRESTORE_EMULATOR_PORT=4901 --dart-define=STORAGE_EMULATOR_PORT=4902`. Those two defines exist for exactly that.
- Even with the emulators, the page loads the Firebase JavaScript SDK from Google's CDN, so it needs internet access.
- On Windows, `flutter pub get` needs Developer Mode switched on so plugins can create symlinks.

## Limits worth knowing

- **Web only.** `lib/UI/homescreen.dart` imports `dart:js`, which exists only on the web. A test build on the Dart VM stops with "Dart library 'dart:js' is not available on this platform", and an Android or iOS build hits the same wall. The platform folders are the unmodified Flutter scaffold. I only built and ran the web target.
- **Accounts are not Firebase Authentication.** A user is a document in the Firestore `users` collection with the password stored as plain text, and login compares what you type with that field. That is fine for a coursework demo and not something to put real passwords into.
- **Needs speech support in the browser.** Until the browser's speech recognizer starts, the user picker shows a "Bzzzing..." spinner. Chrome and Edge provide it; I tested neither with a real microphone.
- **Seed data is expected.** The register screen downloads `DEPOLTIMEJ.jpg` from Storage as the default picture, and View Files lists disk documents from the `FileSystem` collection. On an empty backend there is no default picture and no disk, which is what `emulator/seed.mjs` fixes.
- **Tests.** `test/widget_test.dart` is the unmodified Flutter counter template and does not apply to this app.

## Tech stack

Flutter and Dart. `cloud_firestore`, `firebase_storage` and `firebase_core` for the backend, `speech_to_text` and `flutter_tts` for voice, `file_picker` and `open_file` for local files, and `hexagon` for the honeycomb layout.

## Project structure

```
lib/
  main.dart              Entry point, optional emulator switch
  firebase_options.dart  FlutterFire config for the author's Firebase project
  UI/
    loadingscreen.dart   Boot animation
    userscreen.dart      Hexagon user picker
    userRegister.dart    Registration
    userLogin.dart       Login
    homescreen.dart      Home tiles and voice commands
    viewfiles.dart       This PC: the list of disks
    file.dart            Folder and file browser inside a disk
    filescreen.dart      Text editor with Save, Save As, Undo, Redo
emulator/                Firebase emulator config, open rules and seed script
docs/demo.gif            The recording at the top of this page
```

## Security

The Firebase client config files (`ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart`) are committed, as FlutterFire generates them. A Firebase client key identifies the project rather than granting access, but it should still be restricted in the Google Cloud console (APIs and Services, Credentials) to this app's bundle id, and the app's data must be protected by Firestore and Storage security rules. The emulator setup in this repo uses open rules and is for local use only.

## Context

HoneyOS was built as a university project exploring how to model an operating-system interface, with voice as the main input, as a Flutter application backed by a cloud service.
