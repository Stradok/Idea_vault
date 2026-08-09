-- ============================================================
-- Drop tables/bucket made obsolete by the Google Drive storage pivot.
-- Idea data (title, notes, photos, voice notes, cached research/affiliate
-- results) now lives in the user's own Google Drive — see
-- lib/services/idea_store.dart (DriveIdeaStore) and drive_client.dart.
--
-- Kept: `profiles` (still created on sign-in via handle_new_user trigger)
-- and `sponsors` (fallback data source for the affiliate-matches feature).
--
-- DESTRUCTIVE — this permanently deletes any existing rows/files in the
-- tables and bucket below. Only run this after confirming there's no data
-- you still need in them (there are no real users on this project yet, so
-- this should be safe, but run it deliberately, not automatically).
-- Run via: supabase db push  (or run in Supabase SQL editor)
-- ============================================================

drop table if exists public.research_reports;
drop table if exists public.ideas;

-- Storage: policies can be dropped via SQL, but Supabase blocks direct
-- DELETE on storage.objects/storage.buckets — remove the bucket itself via
-- the Dashboard (Storage -> idea-media -> delete) or the Storage API.
drop policy if exists "media_read_own" on storage.objects;
drop policy if exists "media_insert_own" on storage.objects;
drop policy if exists "media_delete_own" on storage.objects;
