import 'dart:convert';

/// HoneyOS users sign in with a username, not an email address. Firebase
/// Authentication wants an email, so the username is mapped to a stable,
/// well-formed address that is never mailed: the hex of the lower-cased
/// username plus a reserved domain. The same username always maps to the same
/// address, and two different usernames never collide.
const String accountEmailDomain = 'honeyos.invalid';

const int maxUsernameLength = 10;
const int minPasswordLength = 6;
const int maxPasswordLength = 10;

String usernameToEmail(String username) {
  final List<int> bytes = utf8.encode(username.trim().toLowerCase());
  final String hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$hex@$accountEmailDomain';
}

/// Returns a sentence for the user when the username is not acceptable, or
/// null when it is fine.
String? validateUsername(String username) {
  final String name = username.trim();
  if (name.isEmpty) return 'Please provide a username.';
  if (name.length > maxUsernameLength) {
    return 'A username can have at most $maxUsernameLength characters.';
  }
  if (RegExp(r'\s').hasMatch(name)) return 'A username cannot contain spaces.';
  return null;
}

/// Firebase Authentication rejects passwords under six characters; the app has
/// always capped them at ten.
String? validatePassword(String password) {
  if (password.isEmpty) return 'Please provide a password.';
  if (password.length < minPasswordLength) {
    return 'Your password needs at least $minPasswordLength characters.';
  }
  if (password.length > maxPasswordLength) {
    return 'A password can have at most $maxPasswordLength characters.';
  }
  return null;
}
