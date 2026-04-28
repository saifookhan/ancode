import 'dart:convert';

/// Parses plain text from a Gemini `generateContent` JSON response body.
String? parseGeminiGenerateContentText(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic>) return null;
  final candidates = decoded['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final first = candidates.first;
  if (first is! Map<String, dynamic>) return null;
  final content = first['content'];
  if (content is! Map<String, dynamic>) return null;
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return null;
  final p0 = parts.first;
  if (p0 is! Map<String, dynamic>) return null;
  final text = p0['text']?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

/// User-visible message when the model is blocked or returns no text.
String geminiBlockedOrEmptyFallback() {
  return 'Non posso rispondere a questa richiesta in questo momento. '
      'Riprova con una domanda diversa o scrivi a support@ancode.it.';
}
