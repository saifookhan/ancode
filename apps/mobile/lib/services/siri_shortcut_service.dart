import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class SiriShortcutService with WidgetsBindingObserver {
  SiriShortcutService._();

  static final SiriShortcutService instance = SiriShortcutService._();

  static const MethodChannel _channel = MethodChannel('ancode/siri');

  final StreamController<String> _searchCodeController = StreamController<String>.broadcast();
  bool _isInitialized = false;

  Stream<String> get searchCodeStream => _searchCodeController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onSiriSearch') return;
      final raw = (call.arguments as String?)?.trim();
      if (raw == null || raw.isEmpty) return;
      _searchCodeController.add(raw);
    });

    await _pullPendingSiriCode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pullPendingSiriCode());
    }
  }

  Future<void> _pullPendingSiriCode() async {
    try {
      final pendingCode = await _channel.invokeMethod<String>('getInitialSiriCode');
      final raw = pendingCode?.trim();
      if (raw != null && raw.isNotEmpty) {
        _searchCodeController.add(raw);
      }
    } catch (_) {
      // Ignore on non-iOS or if native channel is not available.
    }
  }
}
