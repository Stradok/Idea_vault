-- ============================================================
-- Schedules process-ai-queue to run every 2 minutes, processing
-- one ai_request_queue row per run. Keeps Google Custom Search
-- usage (100/day free, shared across every user) deliberate and
-- spread out instead of bursting whenever users happen to open
-- Research/News/For-you at the same time.
--
-- The actual secret value is stored in Supabase Vault (set via
-- `supabase db query`, not committed here) under the name
-- 'queue_cron_secret' — this migration only references it by name.
-- process-ai-queue has verify_jwt disabled (see config.toml) and
-- checks this shared secret itself instead.
-- ============================================================

select cron.schedule(
  'process-ai-queue',
  '*/2 * * * *',
  $$
  select net.http_post(
    url := 'https://dgbzqtgzehzfbtymgksn.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'queue_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
