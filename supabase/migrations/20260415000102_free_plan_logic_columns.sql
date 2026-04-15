-- Columns required by FREE plan lifecycle logic.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    ALTER TABLE public.codes
      ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
      ADD COLUMN IF NOT EXISTS priority_rank INT,
      ADD COLUMN IF NOT EXISTS free_locked BOOLEAN NOT NULL DEFAULT false,
      ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ;

    BEGIN
      ALTER TABLE public.codes
        ADD CONSTRAINT codes_status_check
        CHECK (status IN ('active', 'inactive', 'grace', 'scheduled')) NOT VALID;
    EXCEPTION
      WHEN duplicate_object THEN
        NULL;
    END;

    CREATE INDEX IF NOT EXISTS idx_codes_owner_status ON public.codes(owner_user_id, status);
    CREATE INDEX IF NOT EXISTS idx_codes_owner_priority ON public.codes(owner_user_id, priority_rank);
    CREATE INDEX IF NOT EXISTS idx_codes_free_locked ON public.codes(owner_user_id, free_locked);
  END IF;
END $$;

