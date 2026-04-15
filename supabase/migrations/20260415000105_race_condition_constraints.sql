-- Race condition hardening for simultaneous code creation.
-- Enforce availability at DB level; second conflicting request must fail.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    -- Exclusive ITALIA reserves the normalized code globally (active/scheduled/grace).
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'normalized_code'
    ) AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'is_exclusive_italy'
    ) AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'status'
    ) THEN
      CREATE UNIQUE INDEX IF NOT EXISTS idx_codes_unique_exclusive_active
        ON public.codes (normalized_code)
        WHERE is_exclusive_italy = true
          AND status IN ('active', 'scheduled', 'grace');
    END IF;

    -- Non-exclusive uniqueness is scoped by municipality (active/scheduled/grace).
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'normalized_code'
    ) AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'municipality_id'
    ) AND EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'status'
    ) THEN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'is_exclusive_italy'
      ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS idx_codes_unique_municipality_active
          ON public.codes (normalized_code, municipality_id)
          WHERE COALESCE(is_exclusive_italy, false) = false
            AND status IN ('active', 'scheduled', 'grace');
      ELSE
        CREATE UNIQUE INDEX IF NOT EXISTS idx_codes_unique_municipality_active
          ON public.codes (normalized_code, municipality_id)
          WHERE status IN ('active', 'scheduled', 'grace');
      END IF;
    END IF;
  END IF;
END $$;

