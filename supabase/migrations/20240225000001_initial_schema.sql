-- Enable UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles (extends auth.users)
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Municipalities (Italian Comuni)
CREATE TABLE municipalities (
  istat_code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  province TEXT,
  region TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_municipalities_name ON municipalities(name);
CREATE INDEX idx_municipalities_province ON municipalities(province);

-- Plan configuration (DB-driven, no code changes for pricing)
CREATE TABLE plan_config (
  plan TEXT PRIMARY KEY CHECK (plan IN ('free', 'pro', 'business')),
  max_active_codes INT NOT NULL DEFAULT 5,
  code_expiry_days INT NOT NULL DEFAULT 30,
  max_exclusive_slots INT NOT NULL DEFAULT 0,
  min_code_length INT NOT NULL DEFAULT 1,
  is_editable BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Subscriptions (synced via Stripe webhooks)
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT UNIQUE,
  plan TEXT NOT NULL DEFAULT 'free' REFERENCES plan_config(plan),
  status TEXT NOT NULL DEFAULT 'canceled' CHECK (status IN (
    'active', 'past_due', 'canceled', 'trialing', 'incomplete', 'incomplete_expired'
  )),
  current_period_end TIMESTAMPTZ,
  past_due_since TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_stripe ON subscriptions(stripe_subscription_id);

-- Normalize code helper (uppercase, strip *)
CREATE OR REPLACE FUNCTION normalize_code(raw TEXT)
RETURNS TEXT AS $$
  SELECT upper(regexp_replace(trim(COALESCE(raw, '')), '[\s*]', '', 'g'));
$$ LANGUAGE sql IMMUTABLE;

-- Blacklist (codes that cannot be registered)
CREATE TABLE blacklist (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL,
  normalized_code TEXT NOT NULL GENERATED ALWAYS AS (normalize_code(code)) STORED,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(normalized_code)
);

CREATE INDEX idx_blacklist_code ON blacklist(normalized_code);

-- ANCODEs
CREATE TABLE ancodes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL,
  normalized_code TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('link', 'note')),
  url TEXT,
  note_text TEXT,
  municipality_id TEXT NOT NULL REFERENCES municipalities(istat_code),
  is_exclusive_italy BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'grace', 'scheduled')),
  schedule_start TIMESTAMPTZ,
  schedule_end TIMESTAMPTZ,
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  click_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT ancodes_format CHECK (char_length(normalized_code) <= 30),
  CONSTRAINT ancodes_format_pattern CHECK (normalized_code ~ '^[A-Z0-9]+$'),
  CONSTRAINT ancodes_link_url CHECK (
    (type = 'link' AND url IS NOT NULL AND url != '') OR
    (type = 'note' AND note_text IS NOT NULL)
  )
);

-- Unique: (normalized_code, municipality_id) for non-exclusive
-- Only one active exclusive ITALIA per normalized_code
CREATE UNIQUE INDEX idx_ancodes_unique_comune
  ON ancodes(normalized_code, municipality_id)
  WHERE is_exclusive_italy = false AND status != 'inactive';

CREATE UNIQUE INDEX idx_ancodes_unique_exclusive
  ON ancodes(normalized_code)
  WHERE is_exclusive_italy = true AND status = 'active';

CREATE INDEX idx_ancodes_owner ON ancodes(owner_user_id);
CREATE INDEX idx_ancodes_normalized ON ancodes(normalized_code);
CREATE INDEX idx_ancodes_status ON ancodes(status);
CREATE INDEX idx_ancodes_created ON ancodes(created_at);

-- Priority for downgrade logic
CREATE TABLE ancode_priority (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ancode_id UUID NOT NULL REFERENCES ancodes(id) ON DELETE CASCADE,
  priority_rank INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, ancode_id)
);

CREATE INDEX idx_ancode_priority_user ON ancode_priority(user_id);

-- Search history (user_id nullable for logged-out; don't duplicate same code)
CREATE TABLE search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  searched_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_search_history_user ON search_history(user_id);
CREATE INDEX idx_search_history_searched ON search_history(searched_at);

-- Clicks / analytics
CREATE TABLE clicks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ancode_id UUID NOT NULL REFERENCES ancodes(id) ON DELETE CASCADE,
  referrer TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_clicks_ancode ON clicks(ancode_id);
CREATE INDEX idx_clicks_created ON clicks(created_at);

-- Discount codes (scaffolding)
CREATE TABLE discount_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  percent_off INT,
  quantity INT,
  expiry_at TIMESTAMPTZ,
  targeting_region TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Bulk email audit (scaffolding)
CREATE TABLE bulk_email_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_user_id UUID NOT NULL REFERENCES auth.users(id),
  region_filter TEXT,
  subject TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
