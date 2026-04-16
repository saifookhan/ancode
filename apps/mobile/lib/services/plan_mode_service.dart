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

  static DateTime? subscriptionEnd(User? user) {
    final raw = user?.userMetadata?['subscription_end']?.toString() ?? user?.userMetadata?['subscription_expires_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? computeExpiration({required Ancode code, required String plan, DateTime? subscriptionEndDate}) {
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

  static String expirationLabel({required Ancode code, required String plan, DateTime? subscriptionEndDate}) {
    final expiration = computeExpiration(code: code, plan: plan, subscriptionEndDate: subscriptionEndDate);
    if (plan == free) {
      if (expiration == null) return 'Scadenza: 30 giorni dalla creazione';
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
    // Keep behavior aligned with web service implementation.
    // Minimal branch needed by mobile flows: FREE removes exclusivity.
    if (plan == free) {
      try {
        await client.from('codes').update({'is_exclusive_italy': false}).eq('owner_user_id', userId);
      } catch (_) {}
    }
  }
}
