# Deploy ANCODE web to Vercel

## Fix 404 NOT_FOUND

1. **Set Root Directory**  
   In Vercel: Project → **Settings** → **General** → **Root Directory** → set to **`apps/web`** and Save.  
   (If this is wrong, Vercel serves the repo root and there is no `index.html` → 404.)

2. **Build and output**  
   Vercel does not provide Flutter in the build environment. Use one of these:

   **Option A – Build locally and deploy**
   ```bash
   cd apps/web
   flutter pub get
   flutter build web --release
   npx vercel --prebuilt
   ```
   Or: build as above, then in Vercel set **Build Command** to empty and **Output Directory** to `build/web`, and deploy the built files (e.g. drag-and-drop or connect a branch that contains the build).

   **Option B – GitHub Actions**  
   Add a workflow that runs `flutter build web` in `apps/web`, then deploys the `build/web` folder to Vercel (e.g. with `vercel --prebuilt` or the Vercel GitHub Action).

3. **SPA routing**  
   `apps/web/vercel.json` already has rewrites so that every path (e.g. `/c/CODE`) is served by `index.html`. No extra config needed for client-side routes.

## Environment variables (only in Vercel)

You **only** set env vars in Vercel – no need to add Supabase or Stripe keys to GitHub Secrets.

1. **Vercel**: **Project** → **Settings** → **Environment Variables** → add:
   - `SUPABASE_URL` (e.g. `https://xxxx.supabase.co`)
   - `SUPABASE_ANON_KEY` (your Supabase anon/public key)
   - `STRIPE_PUBLISHABLE_KEY` (optional, e.g. `pk_test_...` or `pk_live_...`)

The deployed app loads this config at runtime from **`/api/config`** (a small serverless function that reads these env vars and returns them to the client). So the build does not need them; only Vercel needs them.

## Optional: GitHub Actions (auto-deploy)

The repo includes `.github/workflows/deploy-vercel.yml`, which builds Flutter web and deploys the `build/web` output (including the `api/` folder) to Vercel.

1. In Vercel: create the project (or use existing), then **Settings** → **General** → copy **Project ID** and **Org ID**.
2. In GitHub: **Settings** → **Secrets and variables** → **Actions** → add **only**:
   - `VERCEL_TOKEN` (from [vercel.com/account/tokens](https://vercel.com/account/tokens))
   - `VERCEL_ORG_ID`
   - `VERCEL_PROJECT_ID`
3. In Vercel, set the env vars above (SUPABASE_URL, SUPABASE_ANON_KEY, optional STRIPE_PUBLISHABLE_KEY).
4. Push to `main`; the workflow will build and deploy. The app will read config from Vercel via `/api/config`.

In the Vercel project, set **Root Directory** to `apps/web` (or leave default if you use only this workflow).

## Summary

| Setting           | Value      |
|------------------|------------|
| Root Directory   | `apps/web` (if using Vercel’s built-in build; optional with GitHub Actions) |
| Output Directory | `build/web` (from `vercel.json`) |
| Build            | Local `flutter build web` + `vercel --prebuilt`, or use the GitHub Action above |

After deploying a valid `build/web` (and having `vercel.json` rewrites in that output), the 404 should stop.
