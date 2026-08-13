-- ============================================================
-- AI request queue: Google Custom Search is on a tight shared
-- daily free quota (100/day, project-wide, not per-user), so
-- Research/News/For-you requests are queued and processed one
-- at a time by process-ai-queue (invoked on a pg_cron schedule)
-- instead of hitting the search API synchronously per request.
--
-- This table is a processing ticket, not idea storage — idea
-- content itself still lives in the user's own Google Drive
-- (see DriveIdeaStore). title/notes here are just a snapshot of
-- what to research, kept only long enough to process the request.
-- ============================================================

create table if not exists public.ai_request_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('research', 'news', 'affiliate')),
  title text not null,
  notes text,
  category text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'done', 'error')),
  result jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists ai_request_queue_pending_idx
  on public.ai_request_queue (created_at)
  where status = 'pending';

alter table public.ai_request_queue enable row level security;

-- Users can create requests and watch their own; only the
-- service-role worker (process-ai-queue, bypasses RLS) updates
-- status/result — no update/delete policy for regular users.
create policy "queue_select_own" on public.ai_request_queue
  for select using (auth.uid() = user_id);
create policy "queue_insert_own" on public.ai_request_queue
  for insert with check (auth.uid() = user_id);

-- Required for the client to receive Realtime postgres_changes
-- events (used to notify "your result is ready" without polling).
alter publication supabase_realtime add table public.ai_request_queue;
