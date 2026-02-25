-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ancodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ancode_priority ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE blacklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE clicks ENABLE ROW LEVEL SECURITY;
ALTER TABLE discount_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bulk_email_logs ENABLE ROW LEVEL SECURITY;

-- Profiles: read own, update own
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- Municipalities: public read
CREATE POLICY "municipalities_select" ON municipalities
  FOR SELECT USING (true);

-- Plan config: public read
CREATE POLICY "plan_config_select" ON plan_config
  FOR SELECT USING (true);

-- Blacklist: public read (for availability check)
CREATE POLICY "blacklist_select" ON blacklist
  FOR SELECT USING (true);

-- Subscriptions: users see own
CREATE POLICY "subscriptions_select_own" ON subscriptions
  FOR SELECT USING (auth.uid() = user_id);

-- Ancodes: public can read active/grace for search (grace filtered in app logic)
-- Grace codes must not appear in public search - enforced in query
CREATE POLICY "ancodes_select_public" ON ancodes
  FOR SELECT USING (
    status IN ('active', 'scheduled') OR
    (status = 'grace' AND owner_user_id = auth.uid())
  );

CREATE POLICY "ancodes_select_own" ON ancodes
  FOR SELECT USING (owner_user_id = auth.uid());

CREATE POLICY "ancodes_insert_own" ON ancodes
  FOR INSERT WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "ancodes_update_own" ON ancodes
  FOR UPDATE USING (owner_user_id = auth.uid());

CREATE POLICY "ancodes_delete_own" ON ancodes
  FOR DELETE USING (owner_user_id = auth.uid());

-- Ancode priority: own only
CREATE POLICY "ancode_priority_all_own" ON ancode_priority
  FOR ALL USING (auth.uid() = user_id);

-- Search history: own only, insert/select
CREATE POLICY "search_history_select_own" ON search_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "search_history_insert" ON search_history
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

-- Clicks: service role / edge function only (no direct client insert for accuracy)
-- Allow read for analytics by owner
CREATE POLICY "clicks_select_own" ON clicks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM ancodes a WHERE a.id = ancode_id AND a.owner_user_id = auth.uid())
  );

-- Admin policies (role = admin)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Discount codes: admin only
CREATE POLICY "discount_codes_admin" ON discount_codes
  FOR ALL USING (is_admin());

-- Bulk email logs: admin only
CREATE POLICY "bulk_email_logs_admin" ON bulk_email_logs
  FOR ALL USING (is_admin());

-- Admin can read all ancodes, subscriptions
CREATE POLICY "ancodes_admin_select" ON ancodes
  FOR SELECT USING (is_admin());

CREATE POLICY "subscriptions_admin_select" ON subscriptions
  FOR SELECT USING (is_admin());

CREATE POLICY "blacklist_admin_all" ON blacklist
  FOR ALL USING (is_admin());
