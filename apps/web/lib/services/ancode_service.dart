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

    await _releaseExpiredGraceCodes(client);

    final normalized = normalizeCodeInput(input);
    if (normalized.isEmpty) {
      return AncodeSearchResult(error: 'Codice non valido');
    }
    // Record search history for logged-in users (dedupe in DB/query)
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      await _recordSearchHistory(client, userId, normalized);
    }

    // Public search priority:
    // 1) active/scheduled exclusive ITALIA
    // 2) active/scheduled municipality-based
    // 3) grace codes (with municipality context)
    final rawRows = await _searchRows(client, normalized);
    final rows = rawRows
        .where((r) {
          final now = DateTime.now().toUtc();
          final status = r['status'];
          if (status == null) return true; // codes table may not have status
          final eligibleState = status == 'active' || status == 'scheduled' || status == 'grace';
          if (!eligibleState) return false;
          final scheduleStart = DateTime.tryParse(r['schedule_start']?.toString() ?? '');
          final scheduleEnd = DateTime.tryParse(r['schedule_end']?.toString() ?? '');
          if (status == 'scheduled' && scheduleStart != null && scheduleStart.isAfter(now)) {
            return false; // scheduled in future is not publicly available yet
          }
          if (scheduleEnd != null && !scheduleEnd.isAfter(now)) {
            return false; // scheduled window ended
          }
          final expiresRaw = r['expires_at']?.toString();
          if (expiresRaw == null || expiresRaw.isEmpty) return true;
          final expiresAt = DateTime.tryParse(expiresRaw);
          if (expiresAt == null) return true;
          return expiresAt.isAfter(now);
        })
        .toList();

    final primary = rows.where((r) => r['status'] != 'grace').toList();
    final grace = rows.where((r) => r['status'] == 'grace').toList();
    final exclusive = primary.where((r) => r['is_exclusive_italy'] == true).toList();
    final comuneBound = primary.where((r) => r['is_exclusive_italy'] != true).toList();

    List<Ancode> matches = [
      ...exclusive.map((r) => _parseAncode(r, normalized)),
      ...comuneBound.map((r) => _parseAncode(r, normalized)),
      ...grace.map((r) => _parseAncode(r, normalized)),
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
      final rawStatus = (r['status']?.toString() ?? 'active').toLowerCase();
      final status = AncodeStatus.values.firstWhere(
        (e) => e.name == rawStatus,
        orElse: () => AncodeStatus.active,
      );
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
        scheduleStart: DateTime.tryParse(r['schedule_start']?.toString() ?? ''),
        scheduleEnd: DateTime.tryParse(r['schedule_end']?.toString() ?? ''),
        status: status,
        createdAt: r['created_at'] != null ? DateTime.tryParse(r['created_at'].toString()) : null,
        updatedAt: r['updated_at'] != null ? DateTime.tryParse(r['updated_at'].toString()) : null,
        expiresAt: r['expires_at'] != null ? DateTime.tryParse(r['expires_at'].toString()) : null,
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

    await _releaseExpiredGraceCodes(client);

    if (await _isReservedByGrace(client, normalizedCode, currentUserId: client.auth.currentUser?.id)) {
      return false;
    }

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

  static Future<List<Municipality>> listMunicipalities({int limit = 20}) async {
    final client = _client;
    if (client == null) return [];
    final res = await client
        .from('municipalities')
        .select()
        .order('name', ascending: true)
        .limit(limit);
    return (res as List)
        .map((r) => Municipality.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Municipality>> searchRegionCities(String query) async {
    final client = _client;
    if (client == null) return [];
    final trimmed = query.trim();
    if (trimmed.length < 2) return listRegionCities();
    final res = await client
        .from('Regions')
        .select('Citta')
        .ilike('Citta', '%$trimmed%')
        .order('Citta', ascending: true)
        .limit(50);
    return _mapRegionCities(res as List);
  }

  static Future<List<Municipality>> listRegionCities() async {
    final client = _client;
    if (client == null) return [];
    final res = await client
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
    final client = _client;
    if (client == null) {
      throw Exception('Servizio non configurato');
    }

    await _releaseExpiredGraceCodes(client);

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
    final normalizedMunicipality = municipalityId.trim().toUpperCase();
    if (normalizedMunicipality.isEmpty) {
      throw Exception('Seleziona un Comune valido');
    }
    final plan = PlanModeService.currentPlan(user);
    final isBusiness = plan == PlanModeService.business;
    final subscriptionEnd = PlanModeService.subscriptionEnd(user);
    final now = DateTime.now().toUtc();
    if ((plan == PlanModeService.pro || plan == PlanModeService.business) &&
        subscriptionEnd != null &&
        !subscriptionEnd.toUtc().isAfter(now)) {
      throw Exception('Abbonamento scaduto: rinnova per creare nuovi codici');
    }
    await PlanModeService.enforcePlanRules(
      client: client,
      userId: user.id,
      plan: plan,
      subscriptionEndDate: subscriptionEnd,
    );

    final minCodeLength = await _minCodeLengthForPlan(client, plan);
    if (normalizedCode.length < minCodeLength) {
      throw Exception('Piano ${plan.toUpperCase()}: lunghezza minima codice $minCodeLength caratteri');
    }

    if (plan == PlanModeService.free) {
      if (isExclusiveItaly) {
        throw Exception('Nel piano FREE i codici esclusivi non sono disponibili');
      }

      final activeCount = await _countActiveCodesForFree(client, user.id);
      if (activeCount >= 5) {
        throw Exception('Piano FREE: massimo 5 codici attivi');
      }

      final lockedByDowngrade = await _hasLockedCodeForUser(client, user.id, normalizedCode);
      if (lockedByDowngrade) {
        throw Exception('Codice bloccato da downgrade FREE. Effettua upgrade per riattivarlo.');
      }
    }

    if (isExclusiveItaly) {
      final allowedExclusiveSlots = await PlanModeService.allowedExclusiveSlots(
        client: client,
        userId: user.id,
        plan: plan,
        subscriptionEndDate: subscriptionEnd,
      );
      if (allowedExclusiveSlots <= 0) {
        throw Exception('Codici esclusivi non disponibili nel piano attuale');
      }
      final currentExclusiveCount = await _countActiveExclusiveCodes(client, user.id);
      if (currentExclusiveCount >= allowedExclusiveSlots) {
        throw Exception('Slot esclusivi esauriti. Acquista add-on mensile o effettua upgrade.');
      }
    } else {
      final activeExclusiveExists = await _hasActiveExclusiveForCode(client, normalizedCode);
      if (activeExclusiveExists) {
        throw Exception('Code no longer available');
      }
    }

    if (!isBusiness && (scheduleStart != null || scheduleEnd != null)) {
      throw Exception('Scheduling disponibile solo per piano Business');
    }
    if (isBusiness) {
      if (scheduleStart != null && scheduleEnd != null && scheduleEnd.isBefore(scheduleStart)) {
        throw Exception('La data di fine deve essere successiva alla data di inizio');
      }
      if (subscriptionEnd != null) {
        if (scheduleStart != null && scheduleStart.isAfter(subscriptionEnd)) {
          throw Exception('La data di inizio non puo superare la scadenza abbonamento');
        }
      }
    }

    final reservedByGrace = await _isReservedByGrace(
      client,
      normalizedCode,
      currentUserId: user.id,
    );
    if (reservedByGrace) {
      throw Exception('Codice riservato al proprietario originale durante il grace period');
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

    if (plan == PlanModeService.free) {
      payload['expires_at'] = DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();
      payload['is_exclusive_italy'] = false;
    } else {
      DateTime? effectiveExpiry = subscriptionEnd;
      if (isBusiness && scheduleEnd != null) {
        effectiveExpiry = subscriptionEnd == null
            ? scheduleEnd
            : (scheduleEnd.isBefore(subscriptionEnd) ? scheduleEnd : subscriptionEnd);
      }
      if (effectiveExpiry != null) {
        payload['expires_at'] = effectiveExpiry.toUtc().toIso8601String();
      }
      if (isBusiness) {
        if (scheduleStart != null) {
          payload['schedule_start'] = scheduleStart.toUtc().toIso8601String();
          if (scheduleStart.isAfter(DateTime.now().toUtc())) {
            payload['status'] = 'scheduled';
          }
        }
        if (scheduleEnd != null) {
          final effectiveScheduleEnd = subscriptionEnd == null
              ? scheduleEnd
              : (scheduleEnd.isBefore(subscriptionEnd) ? scheduleEnd : subscriptionEnd);
          payload['schedule_end'] = effectiveScheduleEnd.toUtc().toIso8601String();
        }
      }
    }

    await _insertCodesFlexible(client, payload);
  }

  static Future<int> _countActiveCodesForFree(SupabaseClient client, String userId) async {
    try {
      final res = await _selectCodesByOwner(
        client: client,
        userId: userId,
        columns: 'id, expires_at, status',
      );
      final now = DateTime.now().toUtc();
      final rows = List<Map<String, dynamic>>.from(res);
      return rows.where((r) {
        final status = (r['status']?.toString() ?? 'active').toLowerCase();
        if (status != 'active') return false;
        final expiresAt = DateTime.tryParse(r['expires_at']?.toString() ?? '');
        if (expiresAt == null) return true;
        return expiresAt.isAfter(now);
      }).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> _countActiveExclusiveCodes(SupabaseClient client, String userId) async {
    try {
      final res = await _selectCodesByOwner(
        client: client,
        userId: userId,
        columns: 'id, status, is_exclusive_italy',
        extraFilter: (q) => q.eq('is_exclusive_italy', true),
      );
      final rows = List<Map<String, dynamic>>.from(res);
      return rows.where((r) {
        final status = (r['status']?.toString() ?? 'active').toLowerCase();
        return status == 'active' || status == 'scheduled';
      }).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> _hasActiveExclusiveForCode(
    SupabaseClient client,
    String normalizedCode,
  ) async {
    try {
      final row = await client
          .from('codes')
          .select('id')
          .eq('normalized_code', normalizedCode)
          .eq('is_exclusive_italy', true)
          .inFilter('status', ['active', 'scheduled', 'grace'])
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasLockedCodeForUser(
    SupabaseClient client,
    String userId,
    String normalizedCode,
  ) async {
    try {
      final rows = await _selectCodesByOwner(
        client: client,
        userId: userId,
        columns: 'id',
        extraFilter: (q) => q.eq('normalized_code', normalizedCode).eq('free_locked', true).limit(1),
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _releaseExpiredGraceCodes(SupabaseClient client) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await client
          .from('codes')
          .update({
            'status': 'inactive',
            'is_exclusive_italy': false,
            'grace_until': null,
            'expired_at': nowIso,
          })
          .eq('status', 'grace')
          .lte('grace_until', nowIso);
    } catch (_) {
      // Compatible with schemas where some columns are missing.
      try {
        await client
            .from('codes')
            .update({
              'status': 'inactive',
              'is_exclusive_italy': false,
            })
            .eq('status', 'grace')
            .lte('grace_until', nowIso);
      } catch (_) {}
    }
  }

  static Future<void> _recordSearchHistory(
    SupabaseClient client,
    String userId,
    String normalizedCode,
  ) async {
    try {
      // Keep latest only per code for this user.
      await client
          .from('search_history')
          .delete()
          .eq('user_id', userId)
          .eq('code', normalizedCode);
      await client.from('search_history').insert({
        'user_id': userId,
        'code': normalizedCode,
      });
    } catch (_) {
      // Non-blocking: search must continue even if history storage fails.
    }
  }

  static Future<bool> _isReservedByGrace(
    SupabaseClient client,
    String normalizedCode, {
    required String? currentUserId,
  }) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await client
          .from('codes')
          .select('owner_user_id')
          .eq('normalized_code', normalizedCode)
          .eq('status', 'grace')
          .eq('is_exclusive_italy', true)
          .or('grace_until.is.null,grace_until.gt.$nowIso')
          .limit(1);
      if ((rows as List).isEmpty) return false;
      final owner = rows.first['owner_user_id']?.toString();
      return owner != null && owner != currentUserId;
    } catch (_) {
      return false;
    }
  }

  static Future<int> _minCodeLengthForPlan(SupabaseClient client, String plan) async {
    try {
      final row = await client
          .from('plan_config')
          .select('min_code_length')
          .eq('plan', plan)
          .maybeSingle();
      final min = row == null ? null : int.tryParse(row['min_code_length'].toString());
      if (min != null && min > 0) return min;
    } catch (_) {}
    if (plan == PlanModeService.pro) return 3;
    if (plan == PlanModeService.business) return 2;
    return 1;
  }

  static String shortlinkFor(String code) => AppConfig.shortlinkFor(code);

  static Future<void> updateCodeMunicipality({
    required String codeId,
    required String municipalityId,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Servizio non configurato');
    }
    final user = client.auth.currentUser;
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

    await client
        .from('codes')
        .update({'municipality_id': normalizedMunicipality})
        .eq('id', codeId)
        .or('owner_user_id.eq.${user.id},owner_user.eq.${user.id},created_by.eq.${user.id}');
  }

  static Future<void> updateCodeDetails({
    required String codeId,
    required String code,
    required AncodeType type,
    required String municipalityId,
    String? url,
    String? noteText,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Servizio non configurato');
    }
    final user = client.auth.currentUser;
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

    await _updateCodeFlexible(client, codeId, values);
  }

  static const List<String> _ownerColumns = ['owner_user_id', 'owner_user', 'created_by'];

  static Future<List<Map<String, dynamic>>> _selectCodesByOwner({
    required SupabaseClient client,
    required String userId,
    required String columns,
    PostgrestTransformBuilder<PostgrestList> Function(PostgrestFilterBuilder<PostgrestList> q)? extraFilter,
  }) async {
    for (final ownerCol in _ownerColumns) {
      try {
        final base = client.from('codes').select(columns).eq(ownerCol, userId);
        final res = await (extraFilter != null ? extraFilter(base) : base);
        return List<Map<String, dynamic>>.from(res as List);
      } catch (_) {}
    }
    return <Map<String, dynamic>>[];
  }

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
        if (msg.contains('duplicate key value violates unique constraint') ||
            msg.contains('23505') ||
            msg.toLowerCase().contains('unique')) {
          throw Exception('Code no longer available');
        }
        final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(msg);
        if (match == null) rethrow;
        final missing = match.group(1);
        if (missing == null || !working.containsKey(missing)) rethrow;
        if (missing == 'title' || missing == 'content_type' || missing == 'area') rethrow;
        working.remove(missing);
      }
    }
  }

  static Future<void> _updateCodeFlexible(
    SupabaseClient client,
    String codeId,
    Map<String, dynamic> values,
  ) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Accedi per modificare il codice');
    }
    final working = Map<String, dynamic>.from(values);
    while (true) {
      Object? lastError;
      for (final ownerColumn in const ['owner_user_id', 'owner_user', 'created_by']) {
        try {
          await client
              .from('codes')
              .update(working)
              .eq('id', codeId)
              .eq(ownerColumn, user.id);
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
