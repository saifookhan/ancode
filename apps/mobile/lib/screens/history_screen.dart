import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/ancode_service.dart';
import 'auth/login_screen.dart';
import 'code_resolve_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load([String? forcedUserId]) async {
    final auth = context.read<AuthService>();
    final userId = forcedUserId ?? Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _history = [];
        _loading = false;
        _lastUserId = null;
      });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('search_history')
          .select('*')
          .eq('user_id', userId)
          .order('searched_at', ascending: false)
          .limit(50);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final r in res as List) {
        final code = (r['code'] as String).toUpperCase().replaceAll(RegExp(r'[\s*]'), '');
        if (!seen.contains(code)) {
          seen.add(code);
          deduped.add({
            'code': code,
            'searched_at': r['searched_at'] ?? r['created_at'] ?? r['updated_at'],
          });
        }
      }
      if (mounted) {
        setState(() {
          _history = deduped;
          _loading = false;
          _lastUserId = userId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _history = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _openHistoryCode(String code) async {
    final result = await AncodeService.search(code);
    if (!mounted) return;
    if (result.uniqueMatch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeResolveScreen(
            code: result.uniqueMatch!.normalizedCode,
            ancode: result.uniqueMatch,
          ),
        ),
      );
      return;
    }
    if (result.multipleMatches != null && result.multipleMatches!.isNotEmpty) {
      final first = result.multipleMatches!.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeResolveScreen(
            code: first.normalizedCode,
            ancode: first,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Codice non trovato')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
    if (userId != null && userId.isNotEmpty && _lastUserId != userId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(userId));
    }
    return Scaffold(
      body: SafeArea(
        child: (userId == null || userId.isEmpty)
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Accedi per vedere la cronologia',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Accedi'),
                    ),
                  ],
                ),
              )
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna ricerca recente',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'History:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: Colors.white,
                                ) ??
                                const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ..._history.map((h) {
                            final code = h['code'] as String? ?? '';
                            final at = h['searched_at'] as String?;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('*$code'),
                              subtitle: at != null ? Text(DateTime.parse(at).toString().substring(0, 16)) : null,
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () => _openHistoryCode(code),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}
