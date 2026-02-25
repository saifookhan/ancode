import 'package:flutter/foundation.dart' show kIsWeb;

/// Check if current URL is a shortlink /c/CODE (web only)
String? getInitialResolveCode() {
  if (!kIsWeb) return null;
  // ignore: avoid_web_libraries_in_flutter
  final location = Uri.base;
  final match = RegExp(r'^/c/([A-Za-z0-9]+)').firstMatch(location.path);
  return match != null ? match.group(1)!.toUpperCase() : null;
}
