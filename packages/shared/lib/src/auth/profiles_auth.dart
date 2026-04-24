import 'package:supabase_flutter/supabase_flutter.dart';

/// Which column on `public.profiles` stores the Supabase Auth user UUID.
enum ProfilesAuthKey {
  userId('user_id'),
  id('id');

  const ProfilesAuthKey(this.columnName);
  final String columnName;
}

ProfilesAuthKey? _cachedProfilesAuthKey;
int? _cachedProfilesAuthKeyClientId;

void _cacheKeyForClient(int clientId, ProfilesAuthKey key) {
  _cachedProfilesAuthKeyClientId = clientId;
  _cachedProfilesAuthKey = key;
}

/// Clears cached profiles schema (e.g. after switching Supabase project in tests).
void clearProfilesAuthKeyCache() {
  _cachedProfilesAuthKey = null;
  _cachedProfilesAuthKeyClientId = null;
}

bool _isMissingColumnError(Object e, String column) {
  final t = e.toString();
  if (!t.contains('42703')) return false;
  if (t.contains('profiles.$column')) return true;
  return t.contains('column $column does not exist');
}

/// Detects `user_id` vs `id` on [profiles] (PostgREST returns 42703 for unknown columns).
Future<ProfilesAuthKey> resolveProfilesAuthKey(SupabaseClient client) async {
  final clientId = identityHashCode(client);
  if (_cachedProfilesAuthKey != null && _cachedProfilesAuthKeyClientId == clientId) {
    return _cachedProfilesAuthKey!;
  }

  try {
    await client.from('profiles').select('user_id').limit(1);
    _cacheKeyForClient(clientId, ProfilesAuthKey.userId);
    return ProfilesAuthKey.userId;
  } catch (e) {
    if (!_isMissingColumnError(e, 'user_id')) rethrow;
  }

  try {
    await client.from('profiles').select('id').limit(1);
    _cacheKeyForClient(clientId, ProfilesAuthKey.id);
    return ProfilesAuthKey.id;
  } catch (e) {
    if (!_isMissingColumnError(e, 'id')) rethrow;
  }

  throw StateError(
    'public.profiles must have a uuid column named user_id or id for auth linkage.',
  );
}

/// Upserts [fields] on [profiles] for [userId], using the correct auth link column.
Future<void> upsertProfileForUserId(
  SupabaseClient client,
  String userId,
  Map<String, dynamic> fields,
) async {
  final key = await resolveProfilesAuthKey(client);
  final link = key.columnName;
  await client.from('profiles').upsert(
        {
          link: userId,
          ...fields,
        },
        onConflict: link,
      );
}

/// Ensures a row exists in `public.profiles` for [user].
///
/// Used before inserting into `codes` when the DB FK targets [profiles].
Future<void> ensureProfileRowForUser(SupabaseClient client, User user) async {
  final key = await resolveProfilesAuthKey(client);
  final link = key.columnName;
  final existing = await client
      .from('profiles')
      .select(link)
      .eq(link, user.id)
      .maybeSingle();
  if (existing != null) return;

  final emailTrim = user.email?.trim();
  final meta = user.userMetadata;
  var combinedName = '';
  if (meta != null) {
    final fullName = meta['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) {
      combinedName = fullName;
    } else {
      final n = meta['name']?.toString().trim() ?? '';
      final s = meta['surname']?.toString().trim() ?? '';
      combinedName = [n, s].where((x) => x.isNotEmpty).join(' ').trim();
    }
  }

  final email = (emailTrim != null && emailTrim.isNotEmpty)
      ? emailTrim
      : 'pending+${user.id}@users.local';

  await client.from('profiles').upsert(
        {
          link: user.id,
          'email': email,
          if (combinedName.isNotEmpty) 'name': combinedName,
          'plan': 'free',
        },
        onConflict: link,
      );
}
