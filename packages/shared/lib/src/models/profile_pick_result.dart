import 'dart:typed_data';

/// Bytes + filename from a profile photo pick (web file input or mobile gallery).
class ProfilePickResult {
  const ProfilePickResult({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}
