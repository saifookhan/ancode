-- Ledger of Stripe payment activity (written by stripe-webhook Edge Function using service role).
-- Drops an existing public.payments table if present so CREATE matches this schema (avoids
-- "column user_id does not exist" when IF NOT EXISTS skipped a legacy/stub table).

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DROP TABLE IF EXISTS public.payments CASCADE;

CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_event_id TEXT NOT NULL UNIQUE,
  stripe_checkout_session_id TEXT,
  stripe_invoice_id TEXT,
  stripe_payment_intent_id TEXT,
  stripe_subscription_id TEXT,
  stripe_customer_id TEXT,
  amount_cents INTEGER,
  currency TEXT NOT NULL DEFAULT 'usd',
  plan TEXT,
  status TEXT NOT NULL,
  event_type TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_user_created ON public.payments(user_id, created_at DESC);
CREATE INDEX idx_payments_checkout_session ON public.payments(stripe_checkout_session_id)
  WHERE stripe_checkout_session_id IS NOT NULL;
CREATE INDEX idx_payments_invoice ON public.payments(stripe_invoice_id)
  WHERE stripe_invoice_id IS NOT NULL;

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select_own" ON public.payments;

CREATE POLICY "payments_select_own"
  ON public.payments
  FOR SELECT
  USING ((SELECT auth.uid()) = payments.user_id);

COMMENT ON TABLE public.payments IS 'Stripe payment records; inserted by stripe-webhook (service role).';
