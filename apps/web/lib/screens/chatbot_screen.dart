import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/ancode_service.dart';
import '../services/plan_mode_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text: "Ciao! Sono l'assistente ANCODE. Come posso aiutarti oggi?",
        isUser: false,
        timestamp: _nowTime(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _nowTime() {
    final n = DateTime.now();
    final hh = n.hour.toString().padLeft(2, '0');
    final mm = n.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<String> _buildGrounding(String userMessage) async {
    final parts = <String>[];
    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (_) {}
    if (user == null) {
      parts.add('Utente: non autenticato (nessun piano personale da metadata).');
    } else {
      final plan = PlanModeService.currentPlan(user);
      final end = PlanModeService.subscriptionEnd(user);
      parts.add(
        'Utente autenticato. Piano (metadata profilo): $plan. '
        'Scadenza abbonamento (se presente): ${end?.toUtc().toIso8601String() ?? "non indicata"}.',
      );
    }
    final codes = extractPotentialNormalizedCodesForGrounding(userMessage);
    for (final code in codes) {
      try {
        final res = await AncodeService.search(code);
        if (res.uniqueMatch != null) {
          final a = res.uniqueMatch!;
          parts.add(
            'DB ricerca pubblica per "$code": 1 risultato — '
            'codice ${a.normalizedCode}, esclusivo_italia=${a.isExclusiveItaly}, '
            'comune_id=${a.municipalityId}, tipo=${a.type.name}, stato=${a.status.name}'
            '${a.expiresAt != null ? ", scadenza=${a.expiresAt!.toUtc().toIso8601String()}" : ""}.',
          );
        } else if ((res.multipleMatches ?? []).isNotEmpty) {
          final list = res.multipleMatches!;
          final desc = list
              .map(
                (e) =>
                    '${e.normalizedCode}(comune:${e.municipalityId},escl:${e.isExclusiveItaly})',
              )
              .join('; ');
          parts.add(
            'DB ricerca pubblica per "$code": ${list.length} risultati — $desc.',
          );
        } else if ((res.similarCodes ?? []).isNotEmpty) {
          parts.add(
            'DB ricerca pubblica per "$code": nessun match esatto. '
            'Codici simili (prefisso): ${res.similarCodes!.join(", ")}.',
          );
        } else {
          parts.add(
            'DB ricerca pubblica per "$code": ${res.error ?? "nessun dato"}.',
          );
        }
      } catch (e) {
        final msg = e.toString();
        parts.add(
          'DB ricerca per "$code": errore tecnico ${msg.length > 140 ? "${msg.substring(0, 140)}..." : msg}.',
        );
      }
    }
    return parts.join('\n');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: _nowTime()));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    final key = resolveGeminiApiKey(dotenvValue: dotenv.env['GEMINI_API_KEY']);
    try {
      final grounding = await _buildGrounding(text);
      final turns = _messages
          .map((m) => AncodeChatTurn(isUser: m.isUser, text: m.text))
          .toList(growable: false);
      final aiText = await AncodeChatbotGeminiClient.complete(
        apiKey: key,
        messages: turns,
        groundingForLastUser: grounding,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: aiText, isUser: false, timestamp: _nowTime()));
        _isSending = false;
      });
    } catch (e, st) {
      debugPrint('Chatbot: $e\n$st');
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Connessione non riuscita. Controlla la rete o riprova tra poco.',
            isUser: false,
            timestamp: _nowTime(),
          ),
        );
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 14, 10, 8),
                    child: Text(
                      'Chatbot ANCODE',
                      style: TextStyle(
                        color: AppColors.bluUniversoDeep,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 14),
                    child: Text(
                      'Il tuo assistente virtuale',
                      style: TextStyle(
                        color: AppColors.bluUniversoDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFD7DBE2)),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 44, top: 6),
                            child: Text(
                              'ANCODE sta scrivendo...',
                              style: TextStyle(
                                color: Color(0xFF8A93A4),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        final msg = _messages[index];
                        if (msg.isUser) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  constraints: const BoxConstraints(maxWidth: 260),
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.bluUniversoDeep,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        msg.timestamp,
                                        style: const TextStyle(
                                          color: Color(0xFFCFD6E5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: AppColors.limeCreateHard,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.smart_toy_outlined,
                                  size: 16,
                                  color: AppColors.bluUniversoDeep,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 260),
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                decoration: BoxDecoration(
                                  color: AppColors.biancoOttico,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD1D5DE)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.text,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      msg.timestamp,
                                      style: const TextStyle(
                                        color: Color(0xFF8A93A4),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFD7DBE2)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isSending,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Scrivi un messaggio...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8A93A4),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          color: AppColors.bluUniversoDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.bluUniversoDeep,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.limeCreateHard,
                            blurRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final String timestamp;
}
