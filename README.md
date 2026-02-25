# ANCODE

Short, memorable alphanumeric codes (*ANCODEs) that redirect to URLs or display notes. Typable, readable, speakable—no QR required (but QR supported).

## Project Structure

```
ancode/
├── apps/
│   ├── mobile/     # iOS + Android (Flutter)
│   └── web/        # Web app + Admin dashboard (Flutter Web)
├── packages/
│   └── shared/     # Models, API clients, validators, UI kit
├── supabase/
│   ├── migrations/ # Postgres schema
│   ├── functions/  # Edge Functions (Stripe, auth)
│   └── seed.sql    # Seed data
└── docs/           # Feature-wise documentation
```

## Quick Start

### Prerequisites
- Flutter 3.16+
- Supabase CLI (installed via `npm install` in this repo)
- Stripe account

### Setup
1. **Connect Supabase:** See [docs/SETUP_SUPABASE.md](docs/SETUP_SUPABASE.md) – login, link project, push migrations.
2. Copy `apps/web/.env.example` to `apps/web/.env` and fill in:
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY` from your Supabase project
   - `ANCODE_DOMAIN` optional (web uses the current host automatically on Vercel)
   - `STRIPE_PUBLISHABLE_KEY` for subscriptions (optional for MVP)
3. Run migrations: `npm run db:push`
4. Run seed: `npm run db:seed`
5. Start web app: `cd apps/web && flutter run -d chrome`
6. Start mobile: `cd apps/mobile && flutter run`

### Environment Variables
- `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`
- `STRIPE_PUBLISHABLE_KEY` (client)
- `STRIPE_WEBHOOK_SECRET` (server/Edge Functions)
- `ANCODE_DOMAIN` (optional; web uses current host on Vercel)

## Features
- **Public search**: Resolve codes by typing; Comune selector when duplicates exist
- **Create codes**: Link or Note, Comune-bound; Exclusive (Italia-wide) for PRO/BUSINESS
- **Subscriptions**: FREE (5 codes, 30d), PRO, BUSINESS via Stripe
- **Admin dashboard**: Codes, subscriptions, blacklist, discount codes
- **QR + PDF export**: Download/share shortlinks and print layouts

See `/docs` for per-feature documentation.
