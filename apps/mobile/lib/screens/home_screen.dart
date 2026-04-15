import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/ancode_service.dart';
import '../services/auth_service.dart';
import '../services/siri_shortcut_service.dart';
import 'code_resolve_screen.dart';
import 'create_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _codeInputFormatter = _UppercaseAlnumFormatter(maxLength: 30);
  final _controller = TextEditingController();
  AncodeSearchResult? _lastResult;
  bool _isSearching = false;
  StreamSubscription<String>? _siriSubscription;

  void _onControllerChanged() => setState(() {});

  String _normalizeCodeInput(String value) {
    final cleaned = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.length > 30 ? cleaned.substring(0, 30) : cleaned;
  }

  void _onCodeChanged(String value) {
    final normalized = _normalizeCodeInput(value);
    if (normalized == value) return;
    _controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _siriSubscription = SiriShortcutService.instance.searchCodeStream.listen(_onSiriSearchCode);
  }

  @override
  void dispose() {
    _siriSubscription?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSiriSearchCode(String code) {
    final cleanedCode = _normalizeCodeInput(code);
    if (cleanedCode.isEmpty || !mounted) return;
    _controller.text = cleanedCode;
    _controller.selection = TextSelection.collapsed(offset: cleanedCode.length);
    _onSearchSubmitted(cleanedCode);
  }

  void _onSearchSubmitted(String value) async {
    final normalized = _normalizeCodeInput(value);
    if (normalized.isEmpty) return;
    if (_controller.text != normalized) {
      _controller.text = normalized;
      _controller.selection = TextSelection.collapsed(offset: normalized.length);
    }
    setState(() => _isSearching = true);
    try {
      final result = await AncodeService.search(normalized);
      if (mounted) {
        setState(() {
          _lastResult = result;
          _isSearching = false;
        });
        if (result.uniqueMatch != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CodeResolveScreen(
                code: result.uniqueMatch!.normalizedCode,
                ancode: result.uniqueMatch,
              ),
            ),
          ).then((_) => setState(() => _lastResult = null));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = AncodeSearchResult(error: e.toString());
          _isSearching = false;
        });
      }
    }
  }

  static const double _radius = 28;
  static const double _logoSize = 220;
  static const double _limeShadowDy = 6;

  BoxDecoration _limeDropShadowDecoration({
    required Color fill,
    Border? border,
  }) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(_radius),
      border: border,
      boxShadow: [
        BoxShadow(
          color: AppColors.limeNeobrut,
          blurRadius: 0,
          offset: Offset(0, _limeShadowDy),
        ),
      ],
    );
  }

  Widget _navyPillButton({
    VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Widget? child,
  }) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.limeNeobrut,
              blurRadius: 0,
              offset: Offset(0, _limeShadowDy),
            ),
          ],
        ),
        child: Material(
          color: AppColors.bluUniversoDeep,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: child ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: AppColors.biancoOttico, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.biancoOttico,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlinePillButton({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
            color: AppColors.limeNeobrut,
            blurRadius: 0,
            offset: Offset(0, _limeShadowDy),
          ),
        ],
      ),
      child: Material(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0xFFD8D8D8)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.bluUniverso, size: 21),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.bluUniverso,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;
    final auth = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              const AncodeLogo(
                size: _logoSize,
                showName: true,
                logoAssetPath: 'assets/logo.png',
                nameColor: AppColors.bluPolvere,
                nameFontSize: 62,
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: _limeDropShadowDecoration(
                  fill: AppColors.biancoOttico,
                  border: Border.all(color: const Color(0xFFD8D8D8)),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'INSERISCI ANCODE',
                    hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  ),
                  style: const TextStyle(color: AppColors.bluPolvere, fontSize: 18),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  inputFormatters: const [_codeInputFormatter],
                  onChanged: _onCodeChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
              const SizedBox(height: 18),
              _navyPillButton(
                onPressed: _isSearching
                    ? null
                    : () => hasUniqueMatch
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CodeResolveScreen(
                                code: _lastResult!.uniqueMatch!.normalizedCode,
                                ancode: _lastResult!.uniqueMatch,
                              ),
                            ),
                          ).then((_) => setState(() => _lastResult = null))
                        : _onSearchSubmitted(_controller.text),
                icon: Icons.search,
                label: 'CERCA',
                child: _isSearching
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.biancoOttico,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              _outlinePillButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateScreen(
                      prefillCode: _normalizeCodeInput(_controller.text),
                    ),
                  ),
                ),
                icon: Icons.add,
                label: 'CREA',
              ),
              if (auth.isLoggedIn) ...[
                const SizedBox(height: 14),
                _outlinePillButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  icon: Icons.history_rounded,
                  label: 'CRONOLOGIA',
                ),
              ],
              if (_lastResult?.error != null) ...[
                const SizedBox(height: 24),
                Text(_lastResult!.error!, style: const TextStyle(color: AppColors.bluPolvere)),
              ],
              if (_lastResult?.multipleMatches != null && _lastResult!.multipleMatches!.isNotEmpty) ...[
                const SizedBox(height: 24),
                ..._lastResult!.multipleMatches!.map((a) => ListTile(
                      title: Text(a.code, style: const TextStyle(color: AppColors.bluPolvere)),
                      subtitle: Text(a.municipality?.name ?? '', style: const TextStyle(color: AppColors.placeholderGrey)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CodeResolveScreen(code: a.normalizedCode, ancode: a),
                        ),
                      ).then((_) => setState(() => _lastResult = null)),
                    )),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _UppercaseAlnumFormatter extends TextInputFormatter {
  const _UppercaseAlnumFormatter({required this.maxLength});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var normalized = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length > maxLength) {
      normalized = normalized.substring(0, maxLength);
    }
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
