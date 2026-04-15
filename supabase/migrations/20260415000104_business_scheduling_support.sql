-- BUSINESS scheduling support on codes table.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    ALTER TABLE public.codes
      ADD COLUMN IF NOT EXISTS schedule_start TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS schedule_end TIMESTAMPTZ;

    BEGIN
      ALTER TABLE public.codes
        ADD CONSTRAINT codes_schedule_window_check
        CHECK (schedule_end IS NULL OR schedule_start IS NULL OR schedule_end >= schedule_start) NOT VALID;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;

    CREATE INDEX IF NOT EXISTS idx_codes_schedule_start ON public.codes(schedule_start);
    CREATE INDEX IF NOT EXISTS idx_codes_schedule_end ON public.codes(schedule_end);
  END IF;
END $$;

