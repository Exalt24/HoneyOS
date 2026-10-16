import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Profile pictures live inside the user's Firestore document as a small
/// base64 PNG, because Cloud Storage needs a paid Firebase plan. That keeps the
/// whole app on the free Spark plan, and it is why the picture is shrunk first:
/// a document may not exceed 1 MiB and the security rules cap this field.
const int avatarSize = 128;
const String defaultAvatarAsset = 'assets/userSample.png';

/// Shrinks [bytes] (any image format Flutter can decode) to at most
/// [avatarSize] pixels wide and returns it as a PNG.
Future<Uint8List> shrinkAvatar(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: avatarSize);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ByteData? data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (data == null) throw StateError('Could not encode the picture.');
  return data.buffer.asUint8List();
}

/// The picture for a new user: their choice, or the bundled default.
Future<String> encodeAvatar(Uint8List? picked) async {
  final Uint8List source = picked ?? (await rootBundle.load(defaultAvatarAsset)).buffer.asUint8List();
  return base64Encode(await shrinkAvatar(source));
}

Uint8List decodeAvatar(String encoded) => base64Decode(encoded);
