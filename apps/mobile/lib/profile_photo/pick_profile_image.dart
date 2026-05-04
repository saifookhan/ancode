import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/shared.dart';

/// VM / desktop / Android / iOS: gallery via [ImagePicker]; Windows/Linux/macOS via [FilePicker].
Future<ProfilePickResult?> pickProfileImage() async {
  final useImagePicker = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.fuchsia;

  if (useImagePicker) {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return ProfilePickResult(
        bytes: bytes,
        name: picked.name.isNotEmpty ? picked.name : 'photo.jpg',
      );
    } catch (_) {
      return null;
    }
  }

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return ProfilePickResult(
      bytes: bytes,
      name: f.name.isNotEmpty ? f.name : 'photo.jpg',
    );
  } catch (_) {
    return null;
  }
}
