-- Ensure search_history exists and is queryable for logged-in users.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.search_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  searched_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_search_history_user ON public.search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_time ON public.search_history(searched_at DESC);

ALTER TABLE public.search_history ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  BEGIN
    CREATE POLICY "search_history_select_own" ON public.search_history
      FOR SELECT USING (auth.uid() = user_id);
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    CREATE POLICY "search_history_insert_own" ON public.search_history
      FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    CREATE POLICY "search_history_delete_own" ON public.search_history
      FOR DELETE USING (auth.uid() = user_id);
  EXCEPTION
    WHEN duplicate_object THEN NULL;
  END;
END $$;

