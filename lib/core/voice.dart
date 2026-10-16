// Helpers for the "Honey, ... please" voice commands. Pure Dart, so they can be
// unit tested without a browser or a microphone.

/// Everything from the first occurrence of [word] onward, or [input] unchanged
/// when [word] is not there. The recognizer often hears chatter before "honey".
String trimStringFromWord(String input, String word) {
  final int index = input.indexOf(word);
  return index == -1 ? input : input.substring(index);
}

/// The text a command carries after [key] and before the closing " please",
/// for example `valueAfter('honey the username is bob please', 'username is')`
/// gives `bob`. Returns null when [key] is not in the command. A command with
/// no closing "please" yields the rest of the sentence instead of throwing.
String? valueAfter(String command, String key) {
  final int index = command.indexOf(key);
  if (index == -1) return null;
  final int start = index + key.length;
  final int end = command.indexOf(' please', start);
  return command.substring(start, end == -1 ? command.length : end).trim();
}
