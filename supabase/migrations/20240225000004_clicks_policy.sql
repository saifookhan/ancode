-- Allow insert to clicks for anyone (resolver)
CREATE POLICY "clicks_insert" ON clicks
  FOR INSERT WITH CHECK (true);

-- Auto-increment ancode click_count on click insert
CREATE OR REPLACE FUNCTION increment_ancode_click_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE ancodes SET click_count = click_count + 1 WHERE id = NEW.ancode_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_click_insert
  AFTER INSERT ON clicks
  FOR EACH ROW EXECUTE FUNCTION increment_ancode_click_count();
