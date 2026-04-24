-- Allow authenticated users to insert their own profile row; ensure code inserts
-- satisfy FK to profiles. Supports both user_id (repo default) and id (common variant).

DO $$
DECLARE
  profiles_uid_col TEXT;
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RAISE NOTICE 'public.profiles missing; skipped profiles_insert_own and handle_new_user profile logic.';
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'user_id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'user_id';
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'id';
  ELSE
    RAISE EXCEPTION
      'public.profiles must have a uuid column named user_id or id for auth linkage (found neither).';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'profiles_insert_own'
  ) THEN
    EXECUTE format(
      $f$
      CREATE POLICY "profiles_insert_own" ON public.profiles
        FOR INSERT
        WITH CHECK (auth.uid() = %I)
      $f$,
      profiles_uid_col
    );
  END IF;
END $$;

-- Idempotent signup handler: avoid hard failures if a row already exists.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  profiles_uid_col TEXT;
  email_val TEXT;
  name_val TEXT;
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'user_id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'user_id';
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'id';
  ELSE
    RETURN NEW;
  END IF;

  email_val := COALESCE(NULLIF(trim(NEW.email), ''), 'user+' || NEW.id::text || '@local');
  name_val := COALESCE(
    NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'name', '')), ''),
    NULLIF(trim(NEW.email), ''),
    'user+' || NEW.id::text || '@local'
  );

  EXECUTE format(
    $f$
    INSERT INTO public.profiles (%I, email, name)
    VALUES ($1, $2, $3)
    ON CONFLICT (%I) DO NOTHING
    $f$,
    profiles_uid_col,
    profiles_uid_col
  )
  USING NEW.id, email_val, name_val;

  INSERT INTO public.subscriptions (user_id, plan, status)
  VALUES (NEW.id, 'free', 'canceled')
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Before inserting a code, ensure the creator has a profile row (FK to profiles).
CREATE OR REPLACE FUNCTION public.codes_ensure_creator_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  jb JSONB;
  uid_txt TEXT;
  uid UUID;
  profiles_uid_col TEXT;
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'user_id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'user_id';
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'profiles'
      AND c.column_name = 'id'
      AND c.data_type = 'uuid'
  ) THEN
    profiles_uid_col := 'id';
  ELSE
    RETURN NEW;
  END IF;

  jb := to_jsonb(NEW);
  uid_txt := COALESCE(jb ->> 'created_by', jb ->> 'owner_user_id');
  IF uid_txt IS NULL OR uid_txt = '' THEN
    RETURN NEW;
  END IF;

  uid := uid_txt::uuid;

  EXECUTE format(
    $f$
    INSERT INTO public.profiles (%I, email, name)
    SELECT sub.id,
      COALESCE(
        NULLIF(trim(sub.email), ''),
        'pending+' || sub.id::text || '@users.local'
      ),
      NULLIF(
        trim(
          COALESCE(
            sub.raw_user_meta_data ->> 'name',
            sub.raw_user_meta_data ->> 'full_name',
            ''
          )
        ),
        ''
      )
    FROM auth.users sub
    WHERE sub.id = $1
    ON CONFLICT (%I) DO NOTHING
    $f$,
    profiles_uid_col,
    profiles_uid_col
  )
  USING uid;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'codes'
  ) THEN
    DROP TRIGGER IF EXISTS codes_ensure_creator_profile_trigger ON public.codes;
    CREATE TRIGGER codes_ensure_creator_profile_trigger
      BEFORE INSERT ON public.codes
      FOR EACH ROW
      EXECUTE FUNCTION public.codes_ensure_creator_profile();
  END IF;
END $$;
