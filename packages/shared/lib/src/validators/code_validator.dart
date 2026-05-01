import '../constants.dart';

/// Normalizes raw ANCODE input for lookup and storage.
///
/// Trims, removes spoken "asterisk" / "asterisco", strips symbols and spaces,
/// uppercases, and clamps to [kMaxCodeLength]. Siri and URLs may include `*`,
/// punctuation, or dictation artifacts.
String normalizeCodeInput(String input) {
  var s = input.trim();
  // Dart RegExp does not support inline `(?i)`; use caseSensitive: false.
  s = s.replaceAll(RegExp(r'\basterisk\b', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\basterisco\b', caseSensitive: false), '');
  final collapsed = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (collapsed.length <= kMaxCodeLength) return collapsed;
  return collapsed.substring(0, kMaxCodeLength);
}

/// Check format: uppercase letters + digits only, max 30 chars
bool isValidCodeFormat(String normalized) {
  if (normalized.isEmpty) return false;
  if (normalized.length > kMaxCodeLength) return false;
  return kCodeFormatPattern.hasMatch(normalized);
}

/// Validate code; returns null if valid, error message otherwise
String? validateCode(String input) {
  final n = normalizeCodeInput(input);
  if (n.isEmpty) return 'Il codice non può essere vuoto';
  if (n.length > kMaxCodeLength) return 'Massimo $kMaxCodeLength caratteri';
  if (!kCodeFormatPattern.hasMatch(n)) {
    return 'Solo lettere maiuscole e numeri, senza spazi o simboli';
  }
  return null;
}
