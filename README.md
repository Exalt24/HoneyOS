# HoneyOS

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

Firebase is already configured via `lib/firebase_options.dart`. To point the app at your own Firebase project, regenerate it with `flutterfire configure`.

## Context

HoneyOS was built as a university project exploring how to model an operating-system interface as a Flutter application backed by a cloud service.
