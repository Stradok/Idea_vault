# IdeaVault — Plan

## Vision
An app for entrepreneurs to capture business ideas fast and get them from "thought" to "plan": instant research with live sources, relevant news tracking, and matched supplier/partner sponsors.

## Decisions (confirmed)
- **Identity**: Google Sign-In only (no email/password) — bridged into a Supabase session so edge functions can verify callers.
- **Storage**: the user's own Google Drive (`drive.file` scope) — ideas, photos, and voice notes are never stored on our servers. Supabase now only hosts stateless edge functions + `profiles`/`sponsors`.
- **Research**: Perplexity gathers live context → Gemini writes the structured report (RAG). Cached client-side in the idea's own Drive file.
- **News**: as many sources as possible (NewsAPI, GNews, Hacker News, Reddit) then BM25 rerank.
- **"For you" tab**: AI-matched real tools/services per idea (Perplexity→Gemini), falling back to the curated `sponsors` table. Not paid ads — no fabricated affiliate links; turning specific matches into affiliate links is a manual follow-up requiring the user's own program signups.

## Status

### Done
- [x] Flutter app scaffolded (Android, iOS, Linux targets).
- [x] Local mock prototype built and verified (analyze clean, 21 tests, Linux build runs).
- [x] Supabase project created: `dgbzqtgzehzfbtymgksn` (dgbzqtgzehzfbtymgksn.supabase.co).
- [x] Migration `0001_init.sql` pushed: `profiles`, `ideas`, `research_reports`, `sponsors` + RLS + `idea-media` bucket + 10 seed sponsors.
- [x] Edge functions `research` and `news` deployed.
- [x] App rewritten to real Supabase services (no mocks).
- [x] `.env` created (URL + publishable key) and gitignored.
- [x] Tests rewritten for new interfaces; `flutter analyze` clean; `flutter test` 21/21.
- [x] README + this plan file.

- [x] **Production-readiness pass (2026-08-08)**: custom app icon/splash,
      fixed a startup-crash bug (`.env` wasn't a declared Flutter asset),
      Google OAuth deep-link wiring (Android + iOS), in-app account deletion
      (`delete-account` edge function — Play Store requires this), Privacy
      Policy + Terms of Service (linked in-app), Android release signing
      (real keystore generated, gitignored), minify/shrink + desugaring +
      correct NDK/minSdk for the `record` plugin. Installed JDK + Android SDK
      on this machine and produced a real signed `app-release.apk` +
      `app-release.aab`. See `RELEASE_CHECKLIST.md` for the full punch list.

- [x] **Architecture pivot (2026-08-09)**: Google-only auth (native
      `google_sign_in` bridged via `signInWithIdToken`) + all idea data
      (title, notes, photos, voice notes, cached research/affiliate results)
      moved to per-user Google Drive storage (`DriveIdeaStore`,
      `DriveMediaService`, quota-full error handling). New `affiliate-matches`
      edge function replaces the static curated "For you" tab with AI-matched
      real tools per idea (sponsors table kept as fallback only). `research`
      edge function simplified to stateless (no more `ideas`/`research_reports`
      table access — caching moved client-side into Drive). 28/28 tests pass,
      `flutter analyze` clean. See `RELEASE_CHECKLIST.md` §0.5 for what's left
      (Google Cloud Console setup, `GOOGLE_WEB_CLIENT_ID`, and a pending
      destructive migration to drop the now-unused Postgres tables/bucket —
      not run yet, needs explicit go-ahead).

### Blocked / in progress
- [x] Rotate the exposed Supabase service-role key + DB password — done.
- [ ] Google Cloud Console: enable Drive API, add `drive.file` scope + test
      users, create OAuth client IDs (Web/Android) — needed before the new
      auth flow can be tested end-to-end (see README §3).
- [ ] iOS build — deferred by user choice ("Android first"); needs Xcode on
      macOS or a cloud Mac CI, not possible from this Linux machine.

### Needs user input / later
- [ ] **Perplexity API key** (`PERPLEXITY_API_KEY`) — required for Research.
- [ ] **Gemini API key** (`GEMINI_API_KEY`) — required for Research.
- [ ] NewsAPI / GNews keys — optional (HN + Reddit free sources already work).
- [ ] Decide: graceful fallback for Research when keys are missing (currently shows a "try again" error state).
- [ ] AdMob integration (later milestone).
- [ ] Play Store account, store listing, data-safety form — see `RELEASE_CHECKLIST.md`.

## Notes / gotchas
- User's original idea ("link Gemini/Perplexity from the user's Google account") is **not possible**: Perplexity has no OAuth, and Gemini OAuth would use our project's quota, not the user's. Google login is used for **identity only**.
- `sb_secret_...` (service role) and the DB password were exposed in chat once — user must rotate them in the Supabase dashboard.
- Linux run requires patched `linux/CMakeLists.txt` (native_assets guard) + system deps (`clang`, `ninja-build`, GStreamer dev packages).

## Commands
```bash
export PATH="$HOME/flutter/flutter/bin:$HOME/.local/bin:$PATH"
flutter analyze && flutter test
flutter build linux --debug
supabase db push
supabase functions deploy research news
supabase secrets set PERPLEXITY_API_KEY=... GEMINI_API_KEY=...
```
