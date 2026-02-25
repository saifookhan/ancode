# Authentication

ANCODE uses Supabase Auth with email/password. Profiles and subscriptions are created automatically on signup.

## Flow
- **Sign up**: User registers with email; Supabase sends confirmation (if enabled)
- **Sign in**: Email + password
- **Profile**: Auto-created via trigger `handle_new_user`; extends `auth.users`
- **Roles**: `user` (default) or `admin` (set in `profiles.role`)

## RLS
- Users can read/update their own profile
- Admin role checked via `is_admin()` security definer

## Environment
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` for client
- `SUPABASE_SERVICE_ROLE_KEY` for admin operations (server/Edge Functions only)
