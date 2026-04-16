import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:shared/shared.dart';

import '../services/ancode_service.dart' show AncodeService, AncodeSearchResult;
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'code_resolve_screen.dart';
import 'create_screen.dart';
import 'main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _codeInputFormatter = _UppercaseAlnumFormatter(maxLength: 30);
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  AncodeSearchResult? _lastResult;
  bool _isSearching = false;

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
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.removeListener(() => setState(() {}));
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) async {
    final normalized = _normalizeCodeInput(value);
    if (normalized.isEmpty) return;
    if (_controller.text != normalized) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
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
          ).then((_) => _onCodeResolved());
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

  void _onCodeResolved() {
    setState(() => _lastResult = null);
  }

  void _goToContent() {
    if (_lastResult?.uniqueMatch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeResolveScreen(
            code: _lastResult!.uniqueMatch!.normalizedCode,
            ancode: _lastResult!.uniqueMatch,
          ),
        ),
      ).then((_) => _onCodeResolved());
    } else {
      _onSearchSubmitted(_controller.text);
    }
  }

  static const double _radius = 28;
  static const double _logoSize = 160;
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

  @override
  Widget build(BuildContext context) {
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 72),
              const AncodeLogo(
                size: _logoSize,
                showName: true,
                logoAssetPath: 'assets/logo.png',
                subtitle: 'CERCA O CREA',
                subtitleFontSize: 22,
                nameColor: AppColors.lavanda,
                nameFontSize: 44,
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.biancoOttico,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: _limeDropShadowDecoration(
                        fill: AppColors.biancoOttico,
                        border: Border.all(color: const Color(0xFFD8D8D8)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
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
                    const SizedBox(height: 16),
                    _navyPillButton(
                      onPressed: _isSearching
                          ? null
                          : () => hasUniqueMatch ? _goToContent() : _onSearchSubmitted(_controller.text),
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
                    const SizedBox(height: 12),
                    _navyPillButton(
                      onPressed: () {
                        final auth = context.read<AuthService>();
                        if (!auth.isLoggedIn) {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                          );
                          return;
                        }
                        final shell = context.findAncestorStateOfType<MainShellState>();
                        if (shell != null) {
                          shell.goToTab(MainShellState.createIndex);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateScreen(
                              prefillCode: _normalizeCodeInput(_controller.text),
                            ),
                          ),
                        );
                      },
                      icon: Icons.add,
                      label: 'CREA',
                    ),
                  ],
                ),
              ),
              if (_lastResult?.error != null) ...[
                const SizedBox(height: 24),
                Text(_lastResult!.error!, style: const TextStyle(color: AppColors.bluPolvere)),
              ],
              if (_lastResult?.multipleMatches != null && _lastResult!.multipleMatches!.isNotEmpty) ...[
                const SizedBox(height: 24),
                ..._lastResult!.multipleMatches!.map(
                  (a) => ListTile(
                    title: Text(a.code, style: const TextStyle(color: AppColors.bluPolvere)),
                    subtitle: Text(a.municipality?.name ?? '', style: const TextStyle(color: AppColors.placeholderGrey)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodeResolveScreen(
                          code: a.normalizedCode,
                          ancode: a,
                        ),
                      ),
                    ).then((_) => _onCodeResolved()),
                  ),
                ),
              ],
              if (_lastResult != null &&
                  _lastResult!.uniqueMatch == null &&
                  _lastResult!.multipleMatches == null &&
                  _lastResult!.similarCodes != null &&
                  _lastResult!.similarCodes!.isNotEmpty)
                ..._lastResult!.similarCodes!.map(
                  (c) => ListTile(
                    title: Text(c, style: const TextStyle(color: AppColors.bluPolvere)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CodeResolveScreen(code: c)),
                    ).then((_) => _onCodeResolved()),
                  ),
                ),
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
