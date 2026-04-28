import '../constants.dart';
import '../validators/validators.dart';

/// Splits [message] into alphanumeric tokens (including leading `*`).
void _flushToken(StringBuffer buf, Set<String> seen, List<String> out, int max) {
  if (buf.isEmpty || out.length >= max) return;
  final raw = buf.toString();
  buf.clear();
  final n = normalizeCodeInput(raw);
  if (n.length < 2 || n.length > kMaxCodeLength) return;
  if (!RegExp(r'[A-Z]').hasMatch(n)) return;
  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(n)) return;
  if (seen.add(n)) out.add(n);
}

/// Returns distinct normalized code-like tokens from free text for DB grounding.
List<String> extractPotentialNormalizedCodesForGrounding(
  String message, {
  int maxCodes = 5,
}) {
  final seen = <String>{};
  final out = <String>[];
  final buf = StringBuffer();
  for (final rune in message.runes) {
    final c = String.fromCharCode(rune);
    if (RegExp(r'[A-Za-z0-9*]').hasMatch(c)) {
      buf.write(c);
    } else {
      _flushToken(buf, seen, out, maxCodes);
    }
  }
  _flushToken(buf, seen, out, maxCodes);
  return out;
}
