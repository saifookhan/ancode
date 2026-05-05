import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared/shared.dart';

/// Bridges iOS Siri / App Intents and `ancode://` URLs to Flutter search on the home screen.
class SiriShortcutService with WidgetsBindingObserver {
  SiriShortcutService._();

  static final SiriShortcutService instance = SiriShortcutService._();

  static const MethodChannel _channel = MethodChannel('ancode/siri');

  final StreamController<String> _searchCodeController = StreamController<String>.broadcast();
  bool _isInitialized = false;
  String? _deferredNormalizedCode;

  Stream<String> get searchCodeStream => _searchCodeController.stream;

  /// Delivers a code that arrived during cold start before [searchCodeStream] had listeners.
  void consumeDeferredSiriSearchCode(void Function(String code) onCode) {
    final c = _deferredNormalizedCode;
    if (c == null || c.isEmpty) return;
    _deferredNormalizedCode = null;
    onCode(c);
  }

  void _deliverNormalizedSiriCode(String normalized) {
    if (_searchCodeController.hasListener) {
      _searchCodeController.add(normalized);
    } else {
      _deferredNormalizedCode = normalized;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSiriSearch') return;
      final raw = (call.arguments as String?)?.trim();
      if (raw == null || raw.isEmpty) return;
      final normalized = normalizeCodeInput(raw);
      if (normalized.isEmpty) return;
      _deliverNormalizedSiriCode(normalized);
    });

    await _pullPendingSiriCode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pullPendingSiriCode());
    }
  }

  /// Feeds iOS `suggestedEntities()` so Siri can resolve codes you already searched in-app.
  Future<void> rememberLookupCodeForSiri(String code) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final normalized = normalizeCodeInput(code);
    if (normalized.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('rememberRecentCode', normalized);
    } catch (_) {}
  }

  Future<void> _pullPendingSiriCode() async {
    try {
      final pendingCode = await _channel.invokeMethod<String>('getInitialSiriCode');
      final raw = pendingCode?.trim();
      if (raw == null || raw.isEmpty) return;
      final normalized = normalizeCodeInput(raw);
      if (normalized.isEmpty) return;
      _deliverNormalizedSiriCode(normalized);
    } catch (_) {
      // Ignore on non-iOS or if native channel is not available.
    }
  }
}
