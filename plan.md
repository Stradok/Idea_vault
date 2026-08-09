# IdeaVault — Plan

## Vision
An app for entrepreneurs to capture business ideas fast and get them from "thought" to "plan": instant research with live sources, relevant news tracking, and matched supplier/partner sponsors.

## Decisions (confirmed)
- **Backend**: Supabase (accounts, cloud-synced ideas, private storage, edge functions).
- **Research**: Perplexity gathers live context → Gemini writes the structured report (RAG).
- **News**: as many sources as possible (NewsAPI, GNews, Hacker News, Reddit) then BM25 rerank.
- **Ads**: curated sponsors from the DB now; AdMob later.

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

### Blocked / in progress
- [ ] **Rotate the exposed Supabase service-role key + DB password** — still
      the top-priority action only the user can take (Supabase dashboard).
- [x] Google sign-in OAuth client + deep-link redirect are wired in code;
      user still needs to enable the provider in Supabase and add the
      redirect URL (see README §4).
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
