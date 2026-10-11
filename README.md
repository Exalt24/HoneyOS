# HoneyOS

![The HoneyOS boot screen: a bee flies in, the logo and the authors' names fade up](docs/demo.gif)

*The boot animation, recorded from the app. The rest of the app needs a Firebase project (see Getting Started). Full-quality clip: [`assets/LoadingPage.mp4`](assets/LoadingPage.mp4).*

A desktop operating-system simulation built with Flutter, featuring user accounts and a cloud-backed file system. HoneyOS presents an OS-style interface, boot/loading screen, login and registration, a home desktop, and file management screens, with user data and files persisted through Firebase.

## Features

- **OS-style shell** — loading/boot screen into a home desktop environment.
- **User accounts** — registration and login backed by Firebase Authentication.
- **File system** — create, view, and browse files, persisted per user in the cloud.
- **Per-user workspace** — each account has its own files and session.

## Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Authentication + data storage), configured in `lib/firebase_options.dart`

## Project Structure

```
lib/
  main.dart              App entry point
  firebase_options.dart  Firebase configuration
  UI/
    loadingscreen.dart   Boot / loading screen
    userLogin.dart        Login
    userRegister.dart     Registration
    homescreen.dart       Desktop home
    file.dart             File model / screen
    filescreen.dart       File management
    viewfiles.dart        File browser
    userscreen.dart       User / account view
```

## Getting Started

```bash
flutter pub get     # install dependencies
flutter run         # launch on a connected device or emulator
```

The app simulates a desktop operating system, but it runs as a normal Flutter app: `lib/firebase_options.dart` is configured for Android, iOS, web and macOS only, and a Windows or Linux build throws at startup. The Firebase project it points at is the author's, so registration and login need your own: run `flutterfire configure` and replace the generated `firebase_options.dart` and the platform config files. There is no hosted copy, and the only recording in this repo is the boot animation above.

Firebase is already configured via `lib/firebase_options.dart`. To point the app at your own Firebase project, regenerate it with `flutterfire configure`.

## Context

HoneyOS was built as a university project exploring how to model an operating-system interface as a Flutter application backed by a cloud service.
