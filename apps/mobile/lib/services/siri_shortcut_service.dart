import 'dart:async';

import 'package:flutter/services.dart';

class SiriShortcutService {
  SiriShortcutService._();

  static final SiriShortcutService instance = SiriShortcutService._();

  static const MethodChannel _channel = MethodChannel('ancode/siri');

  final StreamController<String> _searchCodeController = StreamController<String>.broadcast();
  bool _isInitialized = false;

  Stream<String> get searchCodeStream => _searchCodeController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSiriSearch') return;
      final raw = (call.arguments as String?)?.trim();
      if (raw == null || raw.isEmpty) return;
      _searchCodeController.add(raw);
    });

    try {
      final initialCode = await _channel.invokeMethod<String>('getInitialSiriCode');
      final raw = initialCode?.trim();
      if (raw != null && raw.isNotEmpty) {
        _searchCodeController.add(raw);
      }
    } catch (_) {
      // Ignore on non-iOS or if native channel is not available.
    }
  }
}
