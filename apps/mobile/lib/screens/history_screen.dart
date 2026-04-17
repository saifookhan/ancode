import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

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

  String _formatTimestamp(String? value) {
    if (value == null || value.isEmpty) return '—';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  Widget _historyTile(Map<String, dynamic> h) {
    final code = h['code'] as String? ?? '';
    final at = _formatTimestamp(h['searched_at'] as String?);
    return WhiteLimePillSurface(
      height: 74,
      shadowDepth: 8,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _openHistoryCode(code),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '*$code',
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          color: AppColors.bluUniversoDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        at,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          color: Color(0xFF6F7686),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.bluUniversoDeep),
              ],
            ),
          ),
        ),
      ),
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
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: (userId == null || userId.isEmpty)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 64, color: Color(0xFF8A90A0)),
                      const SizedBox(height: 14),
                      const Text(
                        'Accedi per vedere la cronologia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 16,
                          color: AppColors.bluPolvere,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 220,
                        child: LimeRailPillButton(
                          label: 'Accedi',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    const SizedBox(height: 2),
                    const Text(
                      'History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: AppColors.bluUniversoDeep,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your recent searches',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        color: Color(0xFF6D7483),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_history.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7E7EB)),
                        ),
                        child: const Text(
                          'Nessuna ricerca recente',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.family,
                            color: Color(0xFF8A90A0),
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      ..._history.map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _historyTile(h),
                          )),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
      ),
    );
  }
}
