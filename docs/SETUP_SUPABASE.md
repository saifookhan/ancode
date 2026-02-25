# Supabase Setup & Connection

This guide walks you through connecting your local project to Supabase so you can manage migrations and data from here without manual steps.

## 1. Install Supabase CLI (done ✓)

Supabase is installed as a project dev dependency. Run commands via:

```bash
npx supabase <command>
# or
npm run db:push
npm run db:seed
# etc.
```

**Alternative (if you prefer global):**  
If Homebrew works on your system: `brew install supabase/tap/supabase`

## 2. Log in to Supabase

```bash
npx supabase login
```

This opens a browser to authenticate with your Supabase account.

## 3. Create a project (if you don't have one)

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click **New Project**
3. Choose org, name, password, region
4. Copy your **Project URL** and **anon key** from Settings → API

## 4. Link this repo to your Supabase project

```bash
npx supabase link --project-ref YOUR_PROJECT_REF
```

Find your Project ref in the dashboard URL:  
`https://supabase.com/dashboard/project/YOUR_PROJECT_REF`

## 5. Push migrations (no manual SQL needed)

```bash
npm run db:push
```

This applies all migrations in `supabase/migrations/` to your remote database.

## 6. Seed initial data (optional)

```bash
npm run db:seed
```

## 7. Supabase Studio (manage everything from the UI)

**Remote (cloud):**  
Use [supabase.com/dashboard](https://supabase.com/dashboard) → your project → Table Editor, SQL Editor, etc.

**Local:**  
If running Supabase locally (`npm run start`), Studio is at:  
`http://localhost:54323`

---

## Common commands

| Task | Command |
|------|---------|
| Push migrations | `npm run db:push` |
| Seed data | `npm run db:seed` |
| Generate migration from schema changes | `npx supabase db diff -f migration_name` |
| Reset local DB (if using local) | `npm run db:reset` |
| Start local Supabase | `npm run start` |
| Stop local Supabase | `npm run stop` |
| Open Studio (local) | `npm run studio` |

---

## Environment variables

After linking, copy your project credentials into:

- `apps/web/.env` (from `apps/web/.env.example`)
- `apps/mobile/.env` (from `apps/mobile/.env.example`)

Required: `SUPABASE_URL`, `SUPABASE_ANON_KEY` from your project’s Settings → API.
