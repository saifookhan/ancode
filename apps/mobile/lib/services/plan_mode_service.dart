import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/shared.dart';

class PlanModeService {
  static const String free = 'free';
  static const String pro = 'pro';
  static const String business = 'business';

  static String currentPlan(User? user) {
    final raw = user?.userMetadata?['plan']?.toString().toLowerCase() ?? free;
    if (raw == pro || raw == business) return raw;
    return free;
  }

  static bool isFree(User? user) => currentPlan(user) == free;

  static DateTime? subscriptionEnd(User? user) {
    final raw = user?.userMetadata?['subscription_end']?.toString() ??
        user?.userMetadata?['subscription_expires_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? computeExpiration({
    required Ancode code,
    required String plan,
    DateTime? subscriptionEndDate,
  }) {
    if (code.expiresAt != null) return code.expiresAt;
    if (plan == free) {
      final created = code.createdAt;
      if (created == null) return null;
      return created.add(const Duration(days: 30));
    }
    return subscriptionEndDate;
  }

  static int? daysLeft(DateTime? expiration) {
    if (expiration == null) return null;
    final now = DateTime.now();
    final diff = expiration.difference(now).inHours;
    if (diff <= 0) return 0;
    return (diff / 24).ceil();
  }

  static String expirationLabel({
    required Ancode code,
    required String plan,
    DateTime? subscriptionEndDate,
  }) {
    final expiration = computeExpiration(
      code: code,
      plan: plan,
      subscriptionEndDate: subscriptionEndDate,
    );

    if (plan == free) {
      if (expiration == null) {
        return 'Scadenza: 30 giorni dalla creazione';
      }
      final left = daysLeft(expiration) ?? 0;
      if (left <= 0) return 'Scaduto';
      return 'Scade tra $left giorni';
    }

    if (expiration != null) {
      final iso = expiration.toLocal().toIso8601String().split('T').first;
      return 'Attivo fino alla scadenza abbonamento: $iso';
    }
    return 'Attivo finche abbonamento $plan e valido';
  }

  static Future<void> enforcePlanRules({
    required SupabaseClient client,
    required String userId,
    required String plan,
    DateTime? subscriptionEndDate,
  }) async {
    final now = DateTime.now().toUtc();
    final allowedExclusiveSlotsCount = await allowedExclusiveSlots(
      client: client,
      userId: userId,
      plan: plan,
      subscriptionEndDate: subscriptionEndDate,
    );

    // Always remove exclusivity on FREE.
    if (plan == free) {
      try {
        await _updateCodesByOwner(
          client: client,
          userId: userId,
          values: {'is_exclusive_italy': false},
          extraFilters: (q) => q.eq('is_exclusive_italy', true),
        );
      } catch (_) {}

      List<Map<String, dynamic>> rows = [];
      try {
        final res = await _selectCodesByOwner(
          client: client,
          userId: userId,
          columns: 'id, created_at, priority_rank',
          orderPriority: true,
        );
        rows = List<Map<String, dynamic>>.from(res);
      } catch (_) {
        final res = await _selectCodesByOwner(
          client: client,
          userId: userId,
          columns: 'id, created_at',
          orderPriority: false,
        );
        rows = List<Map<String, dynamic>>.from(res);
      }

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? now;
        final expiresAt = createdAt.add(const Duration(days: 30));
        final keepByPriority = i < 5;
        final activeByTime = expiresAt.isAfter(now);
        final shouldBeActive = keepByPriority && activeByTime;

        final update = <String, dynamic>{
          'created_plan': free,
          'expires_at': expiresAt.toIso8601String(),
          'status': shouldBeActive ? 'active' : 'inactive',
          'free_locked': !keepByPriority,
          'expired_at': shouldBeActive ? null : now.toIso8601String(),
          'is_exclusive_italy': false,
        };
        await _updateCodeFlexible(client, id, update);
      }
      return;
    }

    // PRO/BUSINESS: unlock FREE-locked codes.
    if (subscriptionEndDate != null && !subscriptionEndDate.toUtc().isAfter(now)) {
      // Subscription expired: non-exclusive inactive, exclusive goes grace (30 days).
      final rows = await client
          .from('codes')
          .select('id, is_exclusive_italy');
      List<Map<String, dynamic>> filteredRows = [];
      for (final ownerCol in _ownerColumns) {
        try {
          final res = await client
              .from('codes')
              .select('id, is_exclusive_italy')
              .eq(ownerCol, userId)
              .inFilter('status', ['active', 'scheduled']);
          filteredRows = List<Map<String, dynamic>>.from(res);
          break;
        } catch (_) {}
      }
      for (final row in filteredRows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final exclusive = row['is_exclusive_italy'] == true;
        final update = <String, dynamic>{
          'created_plan': plan,
          'free_locked': false,
          'expired_at': now.toIso8601String(),
          'status': exclusive ? 'grace' : 'inactive',
          'grace_until': exclusive ? now.add(const Duration(days: 30)).toIso8601String() : null,
        };
        await _updateCodeFlexible(client, id, update);
      }
      return;
    }

    // Active paid subscription: enforce exclusivity slots by priority.
    List<Map<String, dynamic>> rows = [];
    try {
      final res = await client
          .from('codes')
          .select('id, is_exclusive_italy, created_at, priority_rank, status')
          .eq('owner_user_id', userId)
          .order('priority_rank', ascending: true)
          .order('created_at', ascending: true);
      rows = List<Map<String, dynamic>>.from(res);
    } catch (_) {
      final res = await _selectCodesByOwner(
        client: client,
        userId: userId,
        columns: 'id, is_exclusive_italy, created_at, status',
        orderPriority: false,
      );
      rows = List<Map<String, dynamic>>.from(res);
    }

    final exclusiveRows = rows.where((r) => r['is_exclusive_italy'] == true).toList();
    final activeExclusiveIds = exclusiveRows
        .take(allowedExclusiveSlotsCount)
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toSet();

    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final isExclusive = row['is_exclusive_italy'] == true;
      final update = <String, dynamic>{
        'created_plan': plan,
        'free_locked': false,
        'expired_at': null,
      };
      if (subscriptionEndDate != null) {
        update['expires_at'] = subscriptionEndDate.toUtc().toIso8601String();
      }

      if (!isExclusive) {
        update['status'] = 'active';
        update['grace_until'] = null;
        await _updateCodeFlexible(client, id, update);
        continue;
      }

      if (activeExclusiveIds.contains(id)) {
        update['status'] = 'active';
        update['grace_until'] = null;
      } else {
        update['status'] = 'grace';
        update['grace_until'] = now.add(const Duration(days: 30)).toIso8601String();
      }
      await _updateCodeFlexible(client, id, update);
    }
  }

  static Future<int> allowedExclusiveSlots({
    required SupabaseClient client,
    required String userId,
    required String plan,
    DateTime? subscriptionEndDate,
  }) async {
    if (plan == free) return 0;
    final now = DateTime.now().toUtc();
    if (subscriptionEndDate != null && !subscriptionEndDate.toUtc().isAfter(now)) {
      return 0; // add-ons expire with subscription
    }

    var base = 0;
    try {
      final row = await client
          .from('plan_config')
          .select('max_exclusive_slots')
          .eq('plan', plan)
          .maybeSingle();
      base = int.tryParse((row?['max_exclusive_slots'] ?? 0).toString()) ?? 0;
    } catch (_) {
      if (plan == pro) base = 1;
      if (plan == business) base = 10;
    }

    var addon = 0;
    try {
      final user = client.auth.currentUser;
      if (user != null && user.id == userId) {
        addon = int.tryParse((user.userMetadata?['exclusive_addon_slots'] ?? 0).toString()) ?? 0;
      }
    } catch (_) {}
    return base + addon;
  }

  static const List<String> _ownerColumns = ['owner_user_id', 'owner_user', 'created_by'];

  static Future<List<Map<String, dynamic>>> _selectCodesByOwner({
    required SupabaseClient client,
    required String userId,
    required String columns,
    required bool orderPriority,
  }) async {
    for (final ownerCol in _ownerColumns) {
      try {
        final base = client
            .from('codes')
            .select(columns)
            .eq(ownerCol, userId);
        final query = orderPriority
            ? base.order('priority_rank', ascending: true).order('created_at', ascending: true)
            : base.order('created_at', ascending: true);
        final res = await query;
        return List<Map<String, dynamic>>.from(res);
      } catch (_) {}
    }
    return <Map<String, dynamic>>[];
  }

  static Future<void> _updateCodesByOwner({
    required SupabaseClient client,
    required String userId,
    required Map<String, dynamic> values,
    Future<dynamic> Function(dynamic q)? extraFilters,
  }) async {
    for (final ownerCol in _ownerColumns) {
      try {
        final base = client.from('codes').update(values).eq(ownerCol, userId);
        if (extraFilters != null) {
          await extraFilters(base);
        } else {
          await base;
        }
        return;
      } catch (_) {}
    }
  }

  static Future<void> _updateCodeFlexible(
    SupabaseClient client,
    String codeId,
    Map<String, dynamic> update,
  ) async {
    final working = Map<String, dynamic>.from(update);
    while (true) {
      try {
        await client.from('codes').update(working).eq('id', codeId);
        return;
      } catch (e) {
        final msg = e.toString();
        final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(msg);
        if (match == null) rethrow;
        final missing = match.group(1);
        if (missing == null || !working.containsKey(missing)) rethrow;
        working.remove(missing);
      }
    }
  }
}
