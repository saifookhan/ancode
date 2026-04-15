-- Backfill existing codes municipality_id and validate constraint.
-- This makes "municipality is always mandatory" fully enforced for existing rows too.

DO $$
DECLARE
  fallback_municipality TEXT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    -- Pick an existing municipality if available.
    SELECT istat_code
    INTO fallback_municipality
    FROM public.municipalities
    ORDER BY name
    LIMIT 1;

    -- If municipalities table is empty/missing data, create a technical fallback.
    IF fallback_municipality IS NULL THEN
      INSERT INTO public.municipalities (istat_code, name, province, region)
      VALUES ('TECHNICAL_DEFAULT', 'Technical Default', 'N/A', 'N/A')
      ON CONFLICT (istat_code) DO NOTHING;
      fallback_municipality := 'TECHNICAL_DEFAULT';
    END IF;

    -- Backfill invalid municipality values on existing rows.
    UPDATE public.codes
    SET municipality_id = fallback_municipality
    WHERE municipality_id IS NULL
      OR btrim(municipality_id) = ''
      OR upper(municipality_id) = 'ALL';

    -- Validate the check so invalid rows cannot remain.
    BEGIN
      ALTER TABLE public.codes VALIDATE CONSTRAINT codes_municipality_required;
    EXCEPTION
      WHEN undefined_object THEN
        NULL;
    END;
  END IF;
END $$;

