import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import 'app_config.dart';
import 'plan_mode_service.dart';

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
    final rawRows = await _searchRows(normalized);
    final rows = rawRows
        .where((r) {
          final status = r['status'];
          if (status == null) return true;
          return status == 'active' || status == 'scheduled';
        })
        .toList();

    final exclusive = rows.where((r) => r['is_exclusive_italy'] == true).toList();
    final comuneBound = rows.where((r) => r['is_exclusive_italy'] != true).toList();

    List<Ancode> matches = [
      ...exclusive.map((r) => _parseAncode(r, normalized)),
      ...comuneBound.map((r) => _parseAncode(r, normalized)),
    ];

    if (matches.isEmpty) {
      final similar = await _findSimilar(normalized);
      return AncodeSearchResult(error: 'Codice non trovato', similarCodes: similar);
    }
    try {
      final payload = <String, dynamic>{'code': normalized};
      final uid = _client.auth.currentUser?.id;
      if (uid != null) payload['user_id'] = uid;
      await _client.from('search_history').insert(payload);
    } catch (_) {
      // Search should continue even if history tracking fails.
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
    return Ancode.fromJson({...r, 'municipality': m is Map ? m : null});
  }

  static Future<List<String>> _findSimilar(String normalized) async {
    final res = await _client
        .from('codes')
        .select('title')
        .ilike('title', '${normalized.substring(0, normalized.length.clamp(1, 30))}%')
        .limit(5);
    return (res as List)
        .map((r) => (r['normalized_code'] ?? r['title'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Future<List<Municipality>> searchMunicipalities(String query) async {
    if (query.length < 2) return [];
    final res = await _client
        .from('municipalities')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
    return (res as List)
        .map((r) => Municipality.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Municipality>> listMunicipalities({int limit = 20}) async {
    final res = await _client.from('municipalities').select().limit(limit);
    return (res as List).map((r) => Municipality.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<List<Municipality>> searchRegionCities(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return listRegionCities();
    final res = await _client
        .from('Regions')
        .select('Citta')
        .ilike('Citta', '%$trimmed%')
        .order('Citta', ascending: true)
        .limit(50);
    return _mapRegionCities(res as List);
  }

  static Future<List<Municipality>> listRegionCities() async {
    final res = await _client
        .from('Regions')
        .select('Citta')
        .order('Citta', ascending: true)
        .limit(200);
    return _mapRegionCities(res as List);
  }

  static List<Municipality> _mapRegionCities(List rows) {
    final seen = <String>{};
    final mapped = <Municipality>[];
    for (final row in rows) {
      final city = (row as Map<String, dynamic>)['Citta']?.toString().trim() ?? '';
      if (city.isEmpty) continue;
      final key = city.toUpperCase();
      if (!seen.add(key)) continue;
      mapped.add(Municipality(istatCode: key, name: city));
    }
    return mapped;
  }

  static Future<void> createAncode({
    required String code,
    required AncodeType type,
    required String municipalityId,
    required bool isExclusiveItaly,
    String? url,
    String? noteText,
    DateTime? scheduleStart,
    DateTime? scheduleEnd,
  }) async {
    final user = _client.auth.currentUser;
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
      final bl = await _client
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

    final normalizedMunicipality = municipalityId.trim().toUpperCase();
    if (normalizedMunicipality.isEmpty) {
      throw Exception('Seleziona un Comune valido');
    }

    final subscriptionEnd = PlanModeService.subscriptionEnd(user);
    final payload = <String, dynamic>{
      'title': normalizedCode,
      'code': normalizedCode,
      'normalized_code': normalizedCode,
      'type': type == AncodeType.link ? 'link' : 'note',
      'content_type': type == AncodeType.link ? 'link' : 'text',
      'area': type == AncodeType.link ? url?.trim() : noteText?.trim(),
      'content': type == AncodeType.link ? url?.trim() : noteText?.trim(),
      'url': type == AncodeType.link ? url?.trim() : null,
      'note_text': type == AncodeType.note ? noteText?.trim() : null,
      'municipality_id': normalizedMunicipality,
      'owner_user_id': user.id,
      'owner_user': user.id,
      'created_by': user.id,
      'is_exclusive_italy': isExclusiveItaly,
      'status': 'active',
      'created_plan': PlanModeService.currentPlan(user),
      'subscription_snapshot_end': subscriptionEnd?.toUtc().toIso8601String(),
    };
    if (scheduleStart != null) {
      payload['schedule_start'] = scheduleStart.toUtc().toIso8601String();
      if (scheduleStart.isAfter(DateTime.now().toUtc())) {
        payload['status'] = 'scheduled';
      }
    }
    if (scheduleEnd != null) {
      payload['schedule_end'] = scheduleEnd.toUtc().toIso8601String();
    }
    await _insertCodesFlexible(payload);
  }

  static String shortlinkFor(String code) => AppConfig.shortlinkFor(code);

  static Future<void> updateCodeMunicipality({
    required String codeId,
    required String municipalityId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Accedi per modificare il codice');
    }
    final plan = PlanModeService.currentPlan(user);
    if (plan == PlanModeService.free) {
      throw Exception('Nel piano FREE i codici non sono modificabili');
    }

    final normalizedMunicipality = municipalityId.trim().toUpperCase();
    if (normalizedMunicipality.isEmpty) {
      throw Exception('Seleziona un Comune valido');
    }

    final values = <String, dynamic>{
      'municipality_id': normalizedMunicipality,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _updateCodeFlexible(codeId, values, user.id);
  }

  static Future<void> updateCodeDetails({
    required String codeId,
    required String code,
    required AncodeType type,
    required String municipalityId,
    String? url,
    String? noteText,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Accedi per modificare il codice');
    }
    final plan = PlanModeService.currentPlan(user);
    if (plan == PlanModeService.free) {
      throw Exception('Nel piano FREE i codici non sono modificabili');
    }

    final normalizedCode = normalizeCodeInput(code);
    if (normalizedCode.isEmpty || !isValidCodeFormat(normalizedCode)) {
      throw Exception('Codice non valido');
    }
    final normalizedMunicipality = municipalityId.trim().toUpperCase();
    if (normalizedMunicipality.isEmpty) {
      throw Exception('Seleziona un Comune valido');
    }
    if (type == AncodeType.link && (url == null || url.trim().isEmpty)) {
      throw Exception('Inserisci il link');
    }
    if (type == AncodeType.note && (noteText == null || noteText.trim().isEmpty)) {
      throw Exception('Inserisci il testo della nota');
    }

    final values = <String, dynamic>{
      // Keep update payload compatible with minimal/legacy schemas.
      'title': normalizedCode,
      'content_type': type == AncodeType.link ? 'link' : 'text',
      'area': type == AncodeType.link ? url?.trim() : noteText?.trim(),
      'municipality_id': normalizedMunicipality,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _updateCodeFlexible(codeId, values, user.id);
  }

  static Future<List<Map<String, dynamic>>> _searchRows(String normalized) async {
    final res = await _client
        .from('codes')
        .select('*')
        .ilike('title', normalized);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> _insertCodesFlexible(Map<String, dynamic> payload) async {
    final working = Map<String, dynamic>.from(payload);
    while (true) {
      try {
        await _client.from('codes').insert(working);
        return;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('duplicate key value violates unique constraint') ||
            msg.contains('23505') ||
            msg.toLowerCase().contains('unique')) {
          throw Exception('Code no longer available');
        }
        final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(msg);
        if (match == null) rethrow;
        final missing = match.group(1);
        if (missing == null || !working.containsKey(missing)) rethrow;
        // Strip unknown columns (e.g. owner_user_id) for schemas that only use created_by.
        if (missing == 'title' || missing == 'content_type' || missing == 'area') rethrow;
        working.remove(missing);
      }
    }
  }

  static Future<void> _updateCodeFlexible(
    String codeId,
    Map<String, dynamic> values,
    String userId,
  ) async {
    final working = Map<String, dynamic>.from(values);
    while (true) {
      Object? lastError;
      for (final ownerColumn in const ['owner_user_id', 'owner_user', 'created_by']) {
        try {
          await _client
              .from('codes')
              .update(working)
              .eq('id', codeId)
              .eq(ownerColumn, userId);
          return;
        } catch (e) {
          lastError = e;
          final msg = e.toString();
          if (msg.contains("Could not find the '$ownerColumn' column")) {
            continue;
          }
        }
      }
      try {
        if (lastError != null) throw lastError;
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
