import '../constants.dart';

/// Normalize input: strip asterisk, uppercase, remove spaces
String normalizeCodeInput(String input) {
  return input
      .replaceAll(RegExp(r'[\s*]'), '')
      .toUpperCase()
      .trim();
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
