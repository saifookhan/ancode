import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../services/ancode_service.dart';
import 'auth/login_screen.dart';
import 'code_resolve_screen.dart';
import 'create_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final hasUniqueMatch = _lastResult?.uniqueMatch != null;
    final showGoToContent = _isCodeFormatValid && (hasUniqueMatch || _lastResult == null);

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        elevation: 0,
        title: Row(
          children: [
            const Text('*', style: TextStyle(color: AppColors.azzurroCiano, fontSize: 22)),
            const SizedBox(width: 6),
            Text('ANCODE', style: TextStyle(color: AppColors.bluUniverso, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(onPressed: () {}, child: Text('FAQ', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13))),
          TextButton(onPressed: () {}, child: Text('Idee di utilizzo', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13))),
          Consumer<AuthService>(
            builder: (context, auth, _) {
              if (!auth.isLoggedIn) {
                return TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Text('Accedi', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13)),
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () {}, child: Text('Dashboard', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13))),
                  TextButton(onPressed: () {}, child: Text('Profilo', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13))),
                  TextButton(
                    onPressed: () => auth.signOut(),
                    child: Text('Logout', style: TextStyle(color: AppColors.bluPolvere, fontSize: 13)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const AncodeLogo(size: 64, showName: true),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'CASA20',
                  hintStyle: TextStyle(color: AppColors.bluPolvere.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.bluPolvere),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.bluPolvere, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                style: const TextStyle(color: AppColors.bluUniverso, fontSize: 18),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onSubmitted: _onSearchSubmitted,
              ),
              const SizedBox(height: 8),
              if (_controller.text.isNotEmpty)
                Text(
                  _isCodeFormatValid ? 'codice valido ✔' : 'codice non valido',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isCodeFormatValid ? AppColors.bluUniverso : Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 24),
              if (showGoToContent || hasUniqueMatch)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : () => hasUniqueMatch
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verdeCosmico,
                      foregroundColor: AppColors.bluUniverso,
                      side: const BorderSide(color: AppColors.bluPolvere),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _isSearching
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Vai al contenuto'),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSearching ? null : () => _onSearchSubmitted(_controller.text),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.bluUniverso,
                        side: const BorderSide(color: AppColors.bluPolvere),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                            prefillCode: _controller.text.replaceAll(RegExp(r'[\s*]'), '').toUpperCase(),
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bluUniverso,
                        foregroundColor: AppColors.biancoOttico,
                        side: const BorderSide(color: AppColors.verdeCosmico),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text('CREA'),
                    ),
                  ),
                ],
              ),
              if (_lastResult?.error != null) ...[
                const SizedBox(height: 24),
                Text(_lastResult!.error!, style: const TextStyle(color: AppColors.bluPolvere)),
              ],
              if (_lastResult?.multipleMatches != null && _lastResult!.multipleMatches!.isNotEmpty) ...[
                const SizedBox(height: 24),
                ..._lastResult!.multipleMatches!.map((a) => ListTile(
                      title: Text(a.code, style: const TextStyle(color: AppColors.bluUniverso)),
                      subtitle: Text(a.municipality?.name ?? '', style: const TextStyle(color: AppColors.bluPolvere)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CodeResolveScreen(code: a.normalizedCode, ancode: a),
                        ),
                      ).then((_) => setState(() => _lastResult = null)),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
