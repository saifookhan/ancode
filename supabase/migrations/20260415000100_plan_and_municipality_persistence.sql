-- Plan + municipality persistence hardening (codes-first schema)

-- Profiles can store current plan (optional app convenience).
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'free'
  CHECK (plan IN ('free', 'pro', 'business'));

-- Keep subscriptions compatible with plan mode metadata.
ALTER TABLE IF EXISTS public.subscriptions
  ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ;

-- Main codes table adjustments.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    ALTER TABLE public.codes
      ADD COLUMN IF NOT EXISTS municipality_id TEXT,
      ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS created_plan TEXT DEFAULT 'free'
        CHECK (created_plan IN ('free', 'pro', 'business')),
      ADD COLUMN IF NOT EXISTS subscription_snapshot_end TIMESTAMPTZ;

    -- Optional FK if municipalities table exists.
    IF EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'municipalities'
    ) THEN
      BEGIN
        ALTER TABLE public.codes
          ADD CONSTRAINT codes_municipality_fk
          FOREIGN KEY (municipality_id) REFERENCES public.municipalities(istat_code);
      EXCEPTION
        WHEN duplicate_object THEN
          NULL;
      END;
    END IF;

    -- Enforce for new/updated rows without breaking existing historical rows.
    BEGIN
      ALTER TABLE public.codes
        ADD CONSTRAINT codes_municipality_required
        CHECK (municipality_id IS NOT NULL AND municipality_id <> '' AND municipality_id <> 'ALL') NOT VALID;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;

    CREATE INDEX IF NOT EXISTS idx_codes_expires_at ON public.codes(expires_at);
    CREATE INDEX IF NOT EXISTS idx_codes_municipality_id ON public.codes(municipality_id);
  END IF;
END $$;

