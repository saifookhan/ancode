-- Allow code owners to SELECT search_history rows for hits on their own codes.
-- public.codes schemas differ across deployments; owner columns are detected at migrate time.

DROP POLICY IF EXISTS "search_history_select_owned_code_matches" ON public.search_history;

DO $$
DECLARE
  parts text[] := ARRAY[]::text[];
  owner_sql text;
  code_sql text;
  has_norm boolean;
  has_title boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    RAISE NOTICE 'search_history owner policy: public.codes not found; skipped.';
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'owner_user_id'
  ) THEN
    parts := array_append(parts, 'c.owner_user_id = auth.uid()');
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'owner_user'
  ) THEN
    parts := array_append(parts, '(c.owner_user IS NOT NULL AND c.owner_user::text = auth.uid()::text)');
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'created_by'
  ) THEN
    parts := array_append(parts, 'c.created_by = auth.uid()');
  END IF;

  IF coalesce(array_length(parts, 1), 0) = 0 THEN
    RAISE NOTICE 'search_history owner policy: codes has no owner_user_id / owner_user / created_by; skipped.';
    RETURN;
  END IF;

  owner_sql := '(' || array_to_string(parts, ' OR ') || ')';

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'normalized_code'
  ) INTO has_norm;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'codes' AND column_name = 'title'
  ) INTO has_title;

  IF has_norm AND has_title THEN
    code_sql :=
      '((c.normalized_code IS NOT NULL AND c.normalized_code = search_history.code) OR (replace(replace(upper(trim(coalesce(c.title::text, ''''))), '' '', ''''), ''*'', '''') = replace(replace(upper(trim(search_history.code)), '' '', ''''), ''*'', '''')))';
  ELSIF has_norm THEN
    code_sql := '(c.normalized_code IS NOT NULL AND c.normalized_code = search_history.code)';
  ELSIF has_title THEN
    code_sql :=
      '(replace(replace(upper(trim(coalesce(c.title::text, ''''))), '' '', ''''), ''*'', '''') = replace(replace(upper(trim(search_history.code)), '' '', ''''), ''*'', ''''))';
  ELSE
    RAISE NOTICE 'search_history owner policy: codes has no normalized_code or title; skipped.';
    RETURN;
  END IF;

  EXECUTE format(
    $q$
    CREATE POLICY "search_history_select_owned_code_matches"
      ON public.search_history
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.codes c
          WHERE %s
            AND %s
        )
      )
    $q$,
    owner_sql,
    code_sql
  );
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;
