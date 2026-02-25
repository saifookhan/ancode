-- Plan configuration (configurable via DB)
INSERT INTO plan_config (plan, max_active_codes, code_expiry_days, max_exclusive_slots, min_code_length, is_editable)
VALUES
  ('free', 5, 30, 0, 1, false),
  ('pro', 50, 0, 1, 3, true),
  ('business', 500, 0, 10, 2, true)
ON CONFLICT (plan) DO UPDATE SET
  max_active_codes = EXCLUDED.max_active_codes,
  code_expiry_days = EXCLUDED.code_expiry_days,
  max_exclusive_slots = EXCLUDED.max_exclusive_slots,
  min_code_length = EXCLUDED.min_code_length,
  is_editable = EXCLUDED.is_editable;

-- Sample Italian municipalities (subset - full list can be imported separately)
INSERT INTO municipalities (istat_code, name, province, region) VALUES
  ('058091', 'Roma', 'Roma', 'Lazio'),
  ('015146', 'Milano', 'Milano', 'Lombardia'),
  ('063049', 'Napoli', 'Napoli', 'Campania'),
  ('048017', 'Firenze', 'Firenze', 'Toscana'),
  ('021008', 'Bolzano', 'Bolzano', 'Trentino-Alto Adige'),
  ('025032', 'Venezia', 'Venezia', 'Veneto'),
  ('082053', 'Palermo', 'Palermo', 'Sicilia'),
  ('092009', 'Cagliari', 'Cagliari', 'Sardegna'),
  ('036007', 'Bologna', 'Bologna', 'Emilia-Romagna'),
  ('050008', 'Genova', 'Genova', 'Liguria')
ON CONFLICT (istat_code) DO NOTHING;

-- Sample blacklist (optional)
INSERT INTO blacklist (code, reason) VALUES
  ('ADMIN', 'Reserved'),
  ('SUPPORT', 'Reserved')
ON CONFLICT (normalized_code) DO NOTHING;
