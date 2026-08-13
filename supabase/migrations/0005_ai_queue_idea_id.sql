-- ============================================================
-- Links each ai_request_queue row back to the Drive idea it was
-- requested for, so deleting an idea in the app can also cancel
-- (delete) any of its still-pending/queued Research/News/For-you
-- requests instead of leaving orphaned rows behind.
-- ============================================================

alter table public.ai_request_queue
  add column if not exists idea_id uuid;

create index if not exists ai_request_queue_idea_id_idx
  on public.ai_request_queue (idea_id);

-- Previously only insert/select were allowed for normal users (only the
-- service-role worker could update/delete). Deleting an idea needs the
-- client itself to be able to remove that idea's own queue rows.
create policy "queue_delete_own" on public.ai_request_queue
  for delete using (auth.uid() = user_id);
