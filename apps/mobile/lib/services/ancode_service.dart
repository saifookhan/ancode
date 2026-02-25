import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import 'app_config.dart';

class AncodeSearchResult {
  AncodeSearchResult({
    this.uniqueMatch,
    this.multipleMatches,
    this.similarCodes,
    this.error,
  });

  final Ancode? uniqueMatch;
  final List<Ancode>? multipleMatches;
  final List<String>? similarCodes;
  final String? error;
}

class AncodeService {
  static final _client = Supabase.instance.client;

  static Future<AncodeSearchResult> search(String input) async {
    final normalized = normalizeCodeInput(input);
    if (normalized.isEmpty) {
      return AncodeSearchResult(error: 'Codice non valido');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      _client.from('search_history').insert({'user_id': userId, 'code': normalized});
    }

    final res = await _client
        .from('ancodes')
        .select('*, municipality:municipalities(*)')
        .eq('normalized_code', normalized)
        .neq('status', 'grace');

    List<Map<String, dynamic>> rawRows = List<Map<String, dynamic>>.from(res);
    final rows = rawRows
        .where((r) => r['status'] == 'active' || r['status'] == 'scheduled')
        .toList();

    final exclusive = rows.where((r) => r['is_exclusive_italy'] == true).toList();
    final comuneBound = rows.where((r) => r['is_exclusive_italy'] != true).toList();

    List<Ancode> matches = [
      ...exclusive.map((r) => _parseAncode(r)),
      ...comuneBound.map((r) => _parseAncode(r)),
    ];

    if (matches.isEmpty) {
      final similar = await _findSimilar(normalized);
      return AncodeSearchResult(error: 'Codice non trovato', similarCodes: similar);
    }
    if (matches.length == 1) {
      return AncodeSearchResult(uniqueMatch: matches.first);
    }
    return AncodeSearchResult(multipleMatches: matches);
  }

  static Ancode _parseAncode(Map<String, dynamic> r) {
    final m = r['municipality'];
    return Ancode.fromJson({...r, 'municipality': m is Map ? m : null});
  }

  static Future<List<String>> _findSimilar(String normalized) async {
    final res = await _client
        .from('ancodes')
        .select('normalized_code')
        .neq('status', 'grace')
        .like('normalized_code', '${normalized.substring(0, normalized.length.clamp(1, 30))}%')
        .limit(5);
    return (res as List).map((r) => r['normalized_code'] as String).toList();
  }

  static String shortlinkFor(String code) => AppConfig.shortlinkFor(code);
}
