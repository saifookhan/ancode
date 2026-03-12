import 'package:flutter/material.dart';

import 'package:shared/shared.dart';

import '../services/ancode_service.dart' show AncodeService, AncodeSearchResult;
import 'code_resolve_screen.dart';
import 'create_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  AncodeSearchResult? _lastResult;
  bool _isSearching = false;

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
    if (value.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final result = await AncodeService.search(value.trim());
      if (mounted) {
        setState(() {
          _lastResult = result;
          _isSearching = false;
        });
        // Auto-navigate when single match
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
  static const double _greenOutlineWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const AncodeLogo(size: 120, showName: true, logoAssetPath: 'assets/logo.png'),
              const SizedBox(height: 32),
              // One column: input, then CERCA, then CREA (same as mobile)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.biancoOttico,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: AppColors.verdeCosmico, width: _greenOutlineWidth),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.verdeCosmico.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Inserisci ANCODE',
                    hintStyle: TextStyle(color: AppColors.placeholderGrey, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  ),
                  style: const TextStyle(color: AppColors.bluPolvere, fontSize: 18),
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
              const SizedBox(height: 16),
              _outlinedButton(
                onPressed: _isSearching
                    ? null
                    : () => hasUniqueMatch ? _goToContent() : _onSearchSubmitted(_controller.text),
                child: _isSearching
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('CERCA', style: TextStyle(color: AppColors.bluPolvere, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              _filledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateScreen(
                      prefillCode: _controller.text.replaceAll(RegExp(r'[\s*]'), '').toUpperCase(),
                    ),
                  ),
                ),
                child: const Text('CREA', style: TextStyle(color: AppColors.biancoOttico, fontWeight: FontWeight.bold, fontSize: 16)),
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
              if (_lastResult != null && _lastResult!.uniqueMatch == null && _lastResult!.multipleMatches == null && _lastResult!.similarCodes != null && _lastResult!.similarCodes!.isNotEmpty)
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

  Widget _outlinedButton({VoidCallback? onPressed, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.verdeCosmico, width: _greenOutlineWidth),
        boxShadow: [
          BoxShadow(
            color: AppColors.verdeCosmico.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _filledButton({VoidCallback? onPressed, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bluUniverso,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.verdeCosmico, width: _greenOutlineWidth),
        boxShadow: [
          BoxShadow(
            color: AppColors.verdeCosmico.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

