-- PRO/BUSINESS lifecycle support:
-- - grace window for exclusive codes after subscription expiration
-- - pricing-based min length config always available

CREATE TABLE IF NOT EXISTS public.plan_config (
  plan TEXT PRIMARY KEY CHECK (plan IN ('free', 'pro', 'business')),
  max_active_codes INT NOT NULL DEFAULT 5,
  code_expiry_days INT NOT NULL DEFAULT 30,
  max_exclusive_slots INT NOT NULL DEFAULT 0,
  min_code_length INT NOT NULL DEFAULT 1,
  is_editable BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    ALTER TABLE public.codes
      ADD COLUMN IF NOT EXISTS grace_until TIMESTAMPTZ;

    CREATE INDEX IF NOT EXISTS idx_codes_grace_until ON public.codes(grace_until);
  END IF;
END $$;

-- Ensure plan config rows exist for length rules and plan limits.
INSERT INTO public.plan_config (plan, max_active_codes, code_expiry_days, max_exclusive_slots, min_code_length, is_editable)
VALUES
  ('free', 5, 30, 0, 1, false),
  ('pro', 50, 0, 1, 3, true),
  ('business', 500, 0, 10, 2, true)
ON CONFLICT (plan) DO UPDATE
SET
  max_active_codes = EXCLUDED.max_active_codes,
  code_expiry_days = EXCLUDED.code_expiry_days,
  max_exclusive_slots = EXCLUDED.max_exclusive_slots,
  min_code_length = EXCLUDED.min_code_length,
  is_editable = EXCLUDED.is_editable;

