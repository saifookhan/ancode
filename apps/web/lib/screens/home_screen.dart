import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared/shared.dart';

import '../theme/app_theme.dart';
import '../widgets/landing_header.dart';
import '../services/auth_service.dart';
import '../services/ancode_service.dart' show AncodeService, AncodeSearchResult;
import '../services/app_config.dart';
import 'auth/login_screen.dart';
import 'admin/admin_shell.dart';
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

  bool get _isCodeFormatValid {
    final t = _controller.text.replaceAll(RegExp(r'[\s*]'), '').toUpperCase();
    if (t.isEmpty) return false;
    if (t.length > 30) return false;
    return RegExp(r'^[A-Z0-9]+$').hasMatch(t);
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

  @override
  Widget build(BuildContext context) {
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;
    final showGoToContent = _isCodeFormatValid && (hasUniqueMatch || _lastResult == null);

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: LandingHeader(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const AncodeLogo(size: 72, showName: true),
              const SizedBox(height: 40),
              // Oval input
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'CASA20',
                  hintStyle: TextStyle(
                    color: AppColors.bluPolvere.withOpacity(0.6),
                    fontFamily: 'Outfit',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.bluPolvere),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: AppColors.bluPolvere,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: AppColors.verdeCosmico,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                style: const TextStyle(
                  color: AppColors.bluUniverso,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 8),
              // Validation message
              if (_controller.text.isNotEmpty)
                Text(
                  _isCodeFormatValid ? 'codice valido ✔' : 'codice non valido',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isCodeFormatValid
                        ? AppColors.bluUniverso
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 24),
              // Vai al contenuto (when valid / has match)
              if (showGoToContent || hasUniqueMatch)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSearching
                        ? null
                        : () {
                            if (hasUniqueMatch) {
                              _goToContent();
                            } else {
                              _onSearchSubmitted(_controller.text);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verdeCosmico,
                      foregroundColor: AppColors.bluUniverso,
                      side: const BorderSide(color: AppColors.bluPolvere),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Vai al contenuto'),
                  ),
                ),
              const SizedBox(height: 16),
              // CERCA + CREA
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSearching
                          ? null
                          : () => _onSearchSubmitted(_controller.text),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.bluUniverso,
                        side: const BorderSide(color: AppColors.bluPolvere),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text('CERCA'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateScreen(
                            prefillCode: _controller.text
                                .replaceAll(RegExp(r'[\s*]'), '')
                                .toUpperCase(),
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bluUniverso,
                        foregroundColor: AppColors.biancoOttico,
                        side: const BorderSide(color: AppColors.verdeCosmico),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text('CREA'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_lastResult != null)
                _SearchResultWidget(
                  result: _lastResult!,
                  onResolved: _onCodeResolved,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultWidget extends StatelessWidget {
  const _SearchResultWidget({
    required this.result,
    required this.onResolved,
  });

  final AncodeSearchResult result;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context) {
    if (result.error != null) {
      return Card(
        color: AppColors.biancoOttico,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bluPolvere),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Codice non trovato',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(result.error!, style: const TextStyle(color: AppColors.bluPolvere)),
              if (result.similarCodes != null && result.similarCodes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Codici simili:', style: TextStyle(color: AppColors.bluUniverso)),
                ...result.similarCodes!.map(
                  (c) => ListTile(
                    title: Text(c, style: const TextStyle(color: AppColors.bluPolvere)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodeResolveScreen(code: c),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (result.uniqueMatch != null) {
      return Card(
        color: AppColors.verdeCosmico.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.verdeCosmico),
        ),
        child: ListTile(
          title: Text(result.uniqueMatch!.code, style: const TextStyle(color: AppColors.bluUniverso)),
          subtitle: Text(
            result.uniqueMatch!.municipality?.name ?? '',
            style: const TextStyle(color: AppColors.bluPolvere),
          ),
          trailing: const Icon(Icons.arrow_forward, color: AppColors.bluUniverso),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CodeResolveScreen(
                code: result.uniqueMatch!.normalizedCode,
                ancode: result.uniqueMatch,
              ),
            ),
          ).then((_) => onResolved()),
        ),
      );
    }
    if (result.multipleMatches != null && result.multipleMatches!.isNotEmpty) {
      return Card(
        color: AppColors.biancoOttico,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bluPolvere),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleziona Comune',
                style: TextStyle(color: AppColors.bluUniverso, fontWeight: FontWeight.w600),
              ),
              ...result.multipleMatches!.map(
                (a) => ListTile(
                  title: Text(a.code, style: const TextStyle(color: AppColors.bluUniverso)),
                  subtitle: Text(
                    a.municipality?.name ?? '',
                    style: const TextStyle(color: AppColors.bluPolvere),
                  ),
                  trailing: const Icon(Icons.arrow_forward, color: AppColors.bluUniverso),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CodeResolveScreen(
                        code: a.normalizedCode,
                        ancode: a,
                      ),
                    ),
                  ).then((_) => onResolved()),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
