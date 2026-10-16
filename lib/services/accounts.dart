import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/account_rules.dart';

/// A problem with registering or signing in, worded for the person using the
/// app. Its [toString] is the message so the existing error dialogs show it.
class AccountException implements Exception {
  AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What the user picker needs about someone: no secrets, just a name and a
/// picture. The password lives only in Firebase Authentication.
class UserProfile {
  const UserProfile({required this.id, required this.name, required this.picture});

  final String id;
  final String name;

  /// Base64 PNG, see core/avatar.dart.
  final String picture;
}

/// Accounts are Firebase Authentication email/password users whose address is
/// derived from the username (see core/account_rules.dart), plus a profile
/// document at users/{uid}. The Firestore rules key everything off that uid.
class Accounts {
  Accounts({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Everyone shown in the hexagon picker. Readable before sign-in by design.
  Future<List<UserProfile>> listUsers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _users.get();
    return <UserProfile>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs)
        UserProfile(
          id: doc.id,
          name: (doc.data()['name'] as String?) ?? '',
          picture: (doc.data()['profile_picture'] as String?) ?? '',
        ),
    ];
  }

  /// Creates the account and its profile, leaves the new user signed in and
  /// returns the uid.
  Future<String> register({
    required String username,
    required String password,
    required String pictureBase64,
  }) async {
    final String? nameProblem = validateUsername(username);
    if (nameProblem != null) throw AccountException(nameProblem);
    final String? passwordProblem = validatePassword(password);
    if (passwordProblem != null) throw AccountException(passwordProblem);

    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: usernameToEmail(username),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw AccountException('That username is already taken.');
      }
      throw AccountException('Could not register: ${e.message ?? e.code}');
    }
    final String uid = credential.user!.uid;
    await _users.doc(uid).set(<String, Object>{
      'name': username.trim(),
      'profile_picture': pictureBase64,
    });
    return uid;
  }

  /// Signs in and returns the uid, or throws an [AccountException] that says
  /// the password was wrong.
  Future<String> signIn({required String username, required String password}) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: usernameToEmail(username),
        password: password,
      );
      return credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      const Set<String> wrong = <String>{
        'wrong-password',
        'invalid-credential',
        'user-not-found',
        'invalid-email',
      };
      if (wrong.contains(e.code)) throw AccountException('Wrong password.');
      throw AccountException('Could not sign in: ${e.message ?? e.code}');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
