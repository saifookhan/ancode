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
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<AncodeSearchResult> search(String input) async {
    final client = _client;
    if (client == null) {
      return AncodeSearchResult(error: 'Servizio non configurato');
    }

    final normalized = normalizeCodeInput(input);
    if (normalized.isEmpty) {
      return AncodeSearchResult(error: 'Codice non valido');
    }
    // Record search history for logged-in users (dedupe in DB/query)
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      client.from('search_history').insert({
        'user_id': userId,
        'code': normalized,
      });
    }

    // Codes in GRACE must not appear in public search
    final rawRows = await _searchRows(client, normalized);
    final rows = rawRows
        .where((r) {
          final status = r['status'];
          if (status == null) return true; // codes table may not have status
          return status == 'active' || status == 'scheduled';
        })
        .toList();

    // Exclusive ITALIA first
    final exclusive = rows.where((r) => r['is_exclusive_italy'] == true).toList();
    final comuneBound = rows.where((r) => r['is_exclusive_italy'] != true).toList();

    List<Ancode> matches = [
      ...exclusive.map((r) => _parseAncode(r, normalized)),
      ...comuneBound.map((r) => _parseAncode(r, normalized)),
    ];

    if (matches.isEmpty) {
      final similar = await _findSimilar(normalized);
      return AncodeSearchResult(
        error: 'Codice non trovato',
        similarCodes: similar,
      );
    }
    if (matches.length == 1) {
      return AncodeSearchResult(uniqueMatch: matches.first);
    }
    return AncodeSearchResult(multipleMatches: matches);
  }

  static Ancode _parseAncode(Map<String, dynamic> r, String searchedCode) {
    if (r['title'] != null) {
      final title = (r['title']?.toString() ?? searchedCode).trim();
      final contentType = (r['content_type']?.toString() ?? '').toLowerCase();
      final isLink = contentType.contains('link');
      final area = r['area']?.toString();
      return Ancode(
        id: (r['id']?.toString() ?? title),
        code: title,
        normalizedCode: normalizeCodeInput(title),
        type: isLink ? AncodeType.link : AncodeType.note,
        url: isLink ? area : null,
        noteText: isLink ? null : area,
        municipalityId: r['municipality_id']?.toString() ?? 'ALL',
        ownerUserId: r['owner_user_id']?.toString() ?? '',
        isExclusiveItaly: r['is_exclusive_italy'] as bool? ?? false,
      );
    }
    final m = r['municipality'];
    return Ancode.fromJson({
      ...r,
      'municipality': m is Map ? m : null,
    });
  }

  static Future<List<String>> _findSimilar(String normalized) async {
    final client = _client;
    if (client == null) return [];

    final res = await client
        .from('codes')
        .select('title')
        .ilike('title', '${normalized.substring(0, normalized.length.clamp(1, 30))}%')
        .limit(5);
    return (res as List)
        .map((r) => (r['normalized_code'] ?? r['title'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Future<bool> isAvailable(String normalizedCode, String municipalityId) async {
    final client = _client;
    if (client == null) return false;

    try {
      final bl = await client
          .from('blacklist')
          .select('id')
          .eq('normalized_code', normalizedCode)
          .maybeSingle();
      if (bl != null) return false;
    } catch (_) {
      // Blacklist table can be absent in some deployments.
    }

    // Check existing active
    dynamic existing;
    try {
      existing = await client
          .from('codes')
          .select('id')
          .eq('normalized_code', normalizedCode)
          .eq('municipality_id', municipalityId)
          .neq('status', 'inactive')
          .maybeSingle();
    } catch (_) {
      existing = await client
          .from('ancodes')
          .select('id')
          .eq('normalized_code', normalizedCode)
          .eq('municipality_id', municipalityId)
          .neq('status', 'inactive')
          .maybeSingle();
    }
    return existing == null;
  }

  static Future<List<Municipality>> searchMunicipalities(String query) async {
    final client = _client;
    if (client == null) return [];
    if (query.length < 2) return [];
    final res = await client
        .from('municipalities')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
    return (res as List)
        .map((r) => Municipality.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createAncode({
    required String code,
    required AncodeType type,
    required String municipalityId,
    required bool isExclusiveItaly,
    String? url,
    String? noteText,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Servizio non configurato');
    }

    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Accedi per creare codici');
    }

    final normalizedCode = normalizeCodeInput(code);
    if (normalizedCode.isEmpty || !isValidCodeFormat(normalizedCode)) {
      throw Exception('Codice non valido');
    }

    if (type == AncodeType.link && (url == null || url.trim().isEmpty)) {
      throw Exception('Inserisci il link');
    }
    if (type == AncodeType.note && (noteText == null || noteText.trim().isEmpty)) {
      throw Exception('Inserisci il testo della nota');
    }

    try {
      final bl = await client
          .from('blacklist')
          .select('id')
          .eq('normalized_code', normalizedCode)
          .maybeSingle();
      if (bl != null) {
        throw Exception('Codice non disponibile (blacklist)');
      }
    } catch (e) {
      final msg = e.toString();
      if (!(msg.contains('PGRST205') || msg.contains("table 'public.blacklist'"))) {
        rethrow;
      }
    }

    final payload = <String, dynamic>{
      'title': normalizedCode,
      'content_type': type == AncodeType.link ? 'link' : 'text',
      'area': type == AncodeType.link ? url?.trim() : noteText?.trim(),
      'content': type == AncodeType.link ? url?.trim() : noteText?.trim(),
      'municipality_id': municipalityId,
      'owner_user_id': user.id,
      'is_exclusive_italy': isExclusiveItaly,
      'status': 'active',
    };

    await _insertCodesFlexible(client, payload);
  }

  static String shortlinkFor(String code) => AppConfig.shortlinkFor(code);

  static Future<List<Map<String, dynamic>>> _searchRows(
    SupabaseClient client,
    String normalized,
  ) async {
    final res = await client
        .from('codes')
        .select('*')
        .ilike('title', normalized);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> _insertCodesFlexible(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) async {
    final working = Map<String, dynamic>.from(payload);
    while (true) {
      try {
        await client.from('codes').insert(working);
        return;
      } catch (e) {
        final msg = e.toString();
        final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(msg);
        if (match == null) rethrow;
        final missing = match.group(1);
        if (missing == null || !working.containsKey(missing)) rethrow;
        if (missing == 'title' || missing == 'content_type' || missing == 'area') rethrow;
        working.remove(missing);
      }
    }
  }
}
