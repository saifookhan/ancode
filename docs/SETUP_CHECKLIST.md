# ANCODE setup checklist

Use this after cloning or to verify everything is ready.

## Already done (by script / you)

- [x] `.env` files created from examples (`apps/web/.env`, `apps/mobile/.env`)
- [x] Flutter mobile platforms generated (`ios/`, `android/` in `apps/mobile`)
- [x] Flutter dependencies fetched (`packages/shared`, `apps/web`, `apps/mobile`)
- [x] Supabase CLI available (`supabase --version`)
- [x] npm scripts: `db:push`, `db:seed`, `db:setup`, `run:web`, `run:mobile`, `get:all`

## You need to do once

1. **Supabase**
   - [ ] `supabase login`
   - [ ] Create/link project: `supabase link --project-ref YOUR_REF`
   - [ ] Apply DB: `npm run db:setup` (or `db:push` then `db:seed`)

2. **Env**
   - [ ] Edit `apps/web/.env` and `apps/mobile/.env`: set real `SUPABASE_URL` and `SUPABASE_ANON_KEY` (from Supabase dashboard → Settings → API)

3. **Run**
   - [ ] Web: `npm run run:web` or `cd apps/web && flutter run -d chrome`
   - [ ] Mobile: `npm run run:mobile` or `cd apps/mobile && flutter run` (device/emulator)

## Optional

- Set `ANCODE_DOMAIN` and Stripe keys in `.env` when you deploy / add payments
- Make yourself admin: in Supabase Table Editor → `profiles` → set `role` = `admin` for your user
