import '../constants.dart';

bool _isAsciiLetterOrDigit(String unit) {
  if (unit.isEmpty) return false;
  final c = unit.codeUnitAt(0);
  return (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5a) ||
      (c >= 0x61 && c <= 0x7a);
}

/// Removes [word] as a whole word (case-insensitive) without regex word boundaries.
String _removeWholeWordInsensitive(String haystack, String word) {
  if (word.isEmpty || haystack.isEmpty) return haystack;
  final lowerHay = haystack.toLowerCase();
  final lowerWord = word.toLowerCase();
  final wLen = word.length;
  final out = StringBuffer();
  var i = 0;
  while (i < haystack.length) {
    final idx = lowerHay.indexOf(lowerWord, i);
    if (idx < 0) {
      out.write(haystack.substring(i));
      break;
    }
    final left = idx == 0 ? '' : haystack.substring(idx - 1, idx);
    final rightEnd = idx + wLen;
    final right = rightEnd >= haystack.length ? '' : haystack.substring(rightEnd, rightEnd + 1);
    final leftBoundary = left.isEmpty || !_isAsciiLetterOrDigit(left);
    final rightBoundary = right.isEmpty || !_isAsciiLetterOrDigit(right);
    if (leftBoundary && rightBoundary) {
      out.write(haystack.substring(i, idx));
      i = rightEnd;
    } else {
      out.write(haystack.substring(i, idx + 1));
      i = idx + 1;
    }
  }
  return out.toString();
}

/// Collapse to A–Z / 0–9 only and clamp length (no spoken-word stripping).
String _normalizeCodeInputAsciiFold(String input) {
  final collapsed = input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (collapsed.length <= kMaxCodeLength) return collapsed;
  return collapsed.substring(0, kMaxCodeLength);
}

/// Normalizes raw ANCODE input for lookup and storage.
///
/// Trims, removes spoken "asterisk" / "asterisco", strips symbols and spaces,
/// uppercases, and clamps to [kMaxCodeLength]. Siri and URLs may include `*`,
/// punctuation, or dictation artifacts.
String normalizeCodeInput(String input) {
  try {
    var s = input.trim();
    s = _removeWholeWordInsensitive(s, 'asterisk');
    s = _removeWholeWordInsensitive(s, 'asterisco');
    return _normalizeCodeInputAsciiFold(s);
  } on Object {
    return _normalizeCodeInputAsciiFold(input);
  }
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
