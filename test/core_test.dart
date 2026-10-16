import 'package:flutter_test/flutter_test.dart';
import 'package:honey_os/core/account_rules.dart';
import 'package:honey_os/core/voice.dart';

void main() {
  group('voice commands', () {
    test('trimStringFromWord drops the chatter before "honey"', () {
      expect(trimStringFromWord('um so honey tell me the date please', 'honey'), 'honey tell me the date please');
    });

    test('trimStringFromWord leaves a sentence without the word alone', () {
      expect(trimStringFromWord('tell me the date please', 'honey'), 'tell me the date please');
    });

    test('valueAfter reads the value between the key and "please"', () {
      expect(valueAfter('honey the username is bob please', 'username is'), 'bob');
      expect(valueAfter('honey the password is hunter two please', 'password is'), 'hunter two');
    });

    test('valueAfter returns null when the key is missing', () {
      expect(valueAfter('honey tell me the date please', 'username is'), isNull);
    });

    test('valueAfter does not throw when "please" never arrives', () {
      expect(valueAfter('honey the username is bob', 'username is'), 'bob');
    });
  });

  group('account rules', () {
    test('a username maps to a stable, well-formed address', () {
      expect(usernameToEmail('Bob'), '626f62@$accountEmailDomain');
      expect(usernameToEmail('  bob '), usernameToEmail('BOB'));
    });

    test('different usernames never share an address', () {
      expect(usernameToEmail('ann'), isNot(usernameToEmail('anna')));
      expect(usernameToEmail('a.b'), isNot(usernameToEmail('a_b')));
    });

    test('the address is a valid email even for unusual usernames', () {
      final RegExp email = RegExp(r'^[a-z0-9]+@[a-z.]+$');
      for (final String name in <String>['bee', 'Maña', 'x y', 'a+b', '!!!']) {
        expect(email.hasMatch(usernameToEmail(name)), isTrue, reason: name);
      }
    });

    test('validateUsername accepts a plain name and rejects bad ones', () {
      expect(validateUsername('honeybee'), isNull);
      expect(validateUsername(''), isNotNull);
      expect(validateUsername('averyverylongname'), isNotNull);
      expect(validateUsername('two words'), isNotNull);
    });

    test('validatePassword enforces the Firebase minimum and the app maximum', () {
      expect(validatePassword('secret'), isNull);
      expect(validatePassword('short'), contains('at least $minPasswordLength'));
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('waytoolongpassword'), isNotNull);
    });
  });
}
