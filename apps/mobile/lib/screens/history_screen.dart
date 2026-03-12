import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/ancode_service.dart';
import 'code_resolve_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _history = [];
        _loading = false;
      });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('search_history')
          .select('code, searched_at')
          .eq('user_id', user.id)
          .order('searched_at', ascending: false)
          .limit(50);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final r in res as List) {
        final code = (r['code'] as String).toUpperCase().replaceAll(RegExp(r'[\s*]'), '');
        if (!seen.contains(code)) {
          seen.add(code);
          deduped.add(Map<String, dynamic>.from(r));
        }
      }
      if (mounted) {
        setState(() {
          _history = deduped;
          _loading = false;
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

  Future<void> _onTapCode(String code) async {
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
    } else if (result.multipleMatches != null && result.multipleMatches!.length == 1) {
      final a = result.multipleMatches!.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeResolveScreen(code: a.normalizedCode, ancode: a),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Codice non trovato')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: user == null
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
                      onPressed: () =>
                          Provider.of<AuthService>(context, listen: false).signOut(),
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, i) {
                          final h = _history[i];
                          final code = h['code'] as String? ?? '';
                          final at = h['searched_at'] as String?;
                          return ListTile(
                            title: Text('*$code'),
                            subtitle: at != null
                                ? Text(DateTime.parse(at).toString().substring(0, 16))
                                : null,
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => _onTapCode(code),
                          );
                        },
                      ),
      ),
    );
  }
}
