import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ancode_chatbot_gemini.dart';
import 'ancode_chatbot_prompt.dart';

/// One row in the chat transcript for Gemini (`user` / `model`).
class AncodeChatTurn {
  const AncodeChatTurn({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

/// Calls Gemini with ANCODE system rules and optional grounding on the last user turn.
class AncodeChatbotGeminiClient {
  AncodeChatbotGeminiClient._();

  /// `gemini-1.5-flash` often returns 404 on the public API; prefer current IDs.
  static const List<String> _modelFallbacks = <String>[
    'gemini-2.0-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-1.5-flash-latest',
  ];

  /// Builds `contents` for the REST API; skips an initial assistant-only greeting.
  static List<Map<String, dynamic>> buildContents({
    required List<AncodeChatTurn> messages,
    required String groundingForLastUser,
  }) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (i == 0 && !m.isUser) continue;
      var t = m.text;
      if (m.isUser &&
          i == messages.length - 1 &&
          groundingForLastUser.trim().isNotEmpty) {
        t =
            '${m.text}\n\n---\nDATI VERIFICATI DAL SISTEMA (obbligo: non contraddire; '
            'non inventare disponibilita o metriche oltre questi dati):\n'
            '${groundingForLastUser.trim()}';
      }
      out.add({
        'role': m.isUser ? 'user' : 'model',
        'parts': [
          {'text': t},
        ],
      });
    }
    return out;
  }

  /// Returns assistant text or a localized error / empty fallback.
  ///
  /// Never throws: callers (e.g. Flutter UI) should not need a catch for transport/JSON errors.
  static Future<String> complete({
    required String apiKey,
    required List<AncodeChatTurn> messages,
    String groundingForLastUser = '',
  }) async {
    try {
      return await _completeInner(
        apiKey: apiKey,
        messages: messages,
        groundingForLastUser: groundingForLastUser,
      );
    } on Object catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('ClientException') ||
          msg.contains('HandshakeException')) {
        return 'Connessione non riuscita verso il servizio AI. '
            'Controlla la rete o riprova tra poco.';
      }
      return 'Servizio AI temporaneamente non disponibile. Riprova tra poco. '
          '(dettaglio tecnico: ${msg.length > 120 ? "${msg.substring(0, 120)}..." : msg})';
    }
  }

  static Future<String> _completeInner({
    required String apiKey,
    required List<AncodeChatTurn> messages,
    required String groundingForLastUser,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return 'Per le risposte AI serve la chiave Gemini.\n\n'
          'Sviluppo: aggiungi GEMINI_API_KEY in assets/.env (o variabile d’ambiente).\n'
          'Release iOS/Android: passa --dart-define=GEMINI_API_KEY=... nella build '
          '(es. Codemagic).';
    }
    final contents = buildContents(
      messages: messages,
      groundingForLastUser: groundingForLastUser,
    );
    if (contents.isEmpty) {
      return 'Scrivi un messaggio per iniziare.';
    }
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': ancodeChatbotSystemInstruction()},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.65,
        'maxOutputTokens': 640,
      },
    });
    http.Response? response;
    for (final model in _modelFallbacks) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent?key=$key',
      );
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => http.Response('', 408),
          );
      if (response.statusCode != 404) break;
    }
    response = response!;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 408) {
        return 'Timeout della richiesta AI. Controlla la connessione e riprova.';
      }
      final hint = response.statusCode == 404
          ? ' Modello non disponibile per questa chiave.'
          : '';
      return 'Errore AI (${response.statusCode}).$hint Riprova tra poco.';
    }
    try {
      final text = parseGeminiGenerateContentText(response.body);
      if (text != null && text.isNotEmpty) return text;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final candidates = decoded['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, dynamic>) {
            final reason = first['finishReason']?.toString();
            if (reason == 'SAFETY' || reason == 'BLOCKLIST') {
              return geminiBlockedOrEmptyFallback();
            }
          }
        }
      }
    } catch (_) {
      return 'Risposta AI non valida. Riprova tra poco.';
    }
    return geminiBlockedOrEmptyFallback();
  }
}
