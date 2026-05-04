import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:shared/shared.dart';

/// Flutter web: native `<input type="file">` (no `image_picker` method channel).
Future<ProfilePickResult?> pickProfileImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/jpg,image/png,image/webp,image/gif,image/*';
  input.style.display = 'none';
  html.document.body!.append(input);
  input.click();
  try {
    await input.onChange.first.timeout(const Duration(minutes: 15));
  } on TimeoutException {
    input.remove();
    return null;
  }
  try {
    final files = input.files;
    input.remove();
    if (files == null || files.isEmpty) return null;
    final file = files[0];
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    final raw = reader.result;
    if (raw is ByteBuffer) {
      final bytes = Uint8List.view(raw);
      if (bytes.isEmpty) return null;
      final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
      return ProfilePickResult(bytes: bytes, name: name);
    }
    if (raw is Uint8List) {
      if (raw.isEmpty) return null;
      final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
      return ProfilePickResult(bytes: raw, name: name);
    }
    return null;
  } catch (_) {
    return null;
  }
}
