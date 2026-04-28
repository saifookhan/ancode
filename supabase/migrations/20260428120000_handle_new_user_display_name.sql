-- Build display name from auth metadata name + surname (register_screen sends both).

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

  name_val := trim(
    concat_ws(
      ' ',
      NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'name', '')), ''),
      NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'surname', '')), '')
    )
  );
  IF name_val = '' THEN
    name_val := COALESCE(
      NULLIF(trim(COALESCE(NEW.raw_user_meta_data ->> 'full_name', '')), ''),
      NULLIF(trim(NEW.email), ''),
      'user+' || NEW.id::text || '@local'
    );
  END IF;

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
