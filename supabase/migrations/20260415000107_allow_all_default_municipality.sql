-- Align municipality constraint with UI default "All".
-- Keep municipality required, but allow value ALL.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    BEGIN
      ALTER TABLE public.codes DROP CONSTRAINT IF EXISTS codes_municipality_required;
      ALTER TABLE public.codes DROP CONSTRAINT IF EXISTS codes_municipality_not_all;
    EXCEPTION
      WHEN undefined_table THEN NULL;
    END;

    BEGIN
      ALTER TABLE public.codes
        ADD CONSTRAINT codes_municipality_required
        CHECK (municipality_id IS NOT NULL AND municipality_id <> '') NOT VALID;
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

