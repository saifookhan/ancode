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

  static const double _logoSize = 160;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final idleCentered = isPhone && _lastResult == null;
    final topGap = isPhone ? 28.0 : 72.0;
    final logoSectionGap = isPhone ? 16.0 : 28.0;
    final tailGap = isPhone ? 24.0 : 100.0;
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;

    final logoAndCard = <Widget>[
      const AncodeLogo(
        size: _logoSize,
        showName: true,
        logoAssetPath: 'assets/logo.png',
        subtitle: 'CERCA O CREA',
        subtitleFontSize: 22,
        nameColor: AppColors.lavanda,
        nameFontSize: 44,
      ),
      SizedBox(height: logoSectionGap),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
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
            WhiteLimePillSurface(
              height: 58,
              shadowDepth: 8,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'INSERISCI ANCODE',
                  hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
            LimeRailPillButton(
              label: 'CERCA',
              height: 58,
              loading: _isSearching,
              onPressed: _isSearching
                  ? null
                  : () => hasUniqueMatch ? _goToContent() : _onSearchSubmitted(_controller.text),
            ),
            const SizedBox(height: 12),
            WhiteLimePillButton(
              label: 'CREA',
              height: 58,
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
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minH = constraints.maxHeight;
            final scrollChild = idleCentered
                ? Align(
                    // Nudge block upward so space below the card (above bottom nav) is smaller
                    // than true vertical center (full-height Column + center caused a huge gap).
                    alignment: const Alignment(0, -0.42),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: logoAndCard,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      ...logoAndCard,
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
                      SizedBox(height: tailGap),
                    ],
                  );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minH),
                child: scrollChild,
              ),
            );
          },
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
