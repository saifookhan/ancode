import 'package:supabase_flutter/supabase_flutter.dart';

/// Same status rule as the Dashboard "Codici Attivi" list.
bool codeRowIsActiveForPlan(Map<String, dynamic> r) {
  final s = (r['status']?.toString().toLowerCase() ?? 'active');
  return s == 'active' || s == 'scheduled' || s == 'grace';
}

/// Code rows for [userId] (same resolution order as [ProfileScreen] / Dashboard).
Future<List<Map<String, dynamic>>> fetchCodeRowsForUser(
  SupabaseClient client,
  String userId,
) async {
  Future<List<Map<String, dynamic>>?> tryQuery(Future<dynamic> Function() query) async {
    try {
      final res = await query();
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return null;
    }
  }

  final byOwner = await tryQuery(() => client
      .from('codes')
      .select('*')
      .eq('owner_user_id', userId)
      .order('created_at', ascending: false));
  if (byOwner != null) return byOwner;

  final byCreated = await tryQuery(() => client
      .from('codes')
      .select('*')
      .eq('created_by', userId)
      .order('created_at', ascending: false));
  if (byCreated != null) return byCreated;

  try {
    final res = await client
        .from('codes')
        .select('*')
        .eq('created_by', userId)
        .order('priority_rank', ascending: true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {}

  final fromAncodes = await tryQuery(() => client
      .from('ancodes')
      .select('*, municipality:municipalities(*)')
      .eq('owner_user_id', userId)
      .order('created_at', ascending: false));
  if (fromAncodes != null) return fromAncodes;

  return [];
}

/// Active / scheduled / grace codes for plan usage (Profilo, aligned with Dashboard).
Future<int> countActiveCodesForUser(SupabaseClient client, String userId) async {
  final rows = await fetchCodeRowsForUser(client, userId);
  return rows.where(codeRowIsActiveForPlan).length;
}
