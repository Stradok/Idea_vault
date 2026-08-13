# IdeaVault — Plan

## Vision
An app for entrepreneurs to capture business ideas fast and get them from "thought" to "plan": instant research with live sources, relevant news tracking, and matched supplier/partner sponsors.

## Decisions (confirmed)
- **Identity**: Google Sign-In only (no email/password) — bridged into a Supabase session so edge functions can verify callers.
- **Storage**: the user's own Google Drive (`drive.file` scope) — ideas, photos, and voice notes are never stored on our servers. Supabase now only hosts stateless edge functions + `profiles`/`sponsors`.
- **Research**: Tavily gathers live web-search context → Gemini writes the structured report (RAG). Cached client-side in the idea's own Drive file.
- **News**: as many sources as possible (NewsAPI, GNews, Hacker News, Reddit) then BM25 rerank.
- **"For you" tab**: AI-matched real tools/services per idea (Tavily→Gemini), falling back to the curated `sponsors` table. Not paid ads — no fabricated affiliate links; turning specific matches into affiliate links is a manual follow-up requiring the user's own program signups.
- **Free-tier architecture**: replaced the paid Perplexity API with a free search backend + Gemini (already free-tier) — no per-user API keys, no OAuth account-linking (confirmed technically impossible, see Notes below). Started on Google Custom Search (100 free queries/day) but that turned out to be structurally unreliable (see 2026-08-13 entry), so switched to Tavily. Research/News/For-you requests are queued and processed one at a time rather than instantly, both to smooth a shared free-tier key and to keep a small control group's usage predictable.

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

- [x] **Free-tier + queue pivot (2026-08-12)**: replaced Perplexity with
      Google Custom Search JSON API (`GOOGLE_SEARCH_API_KEY`/`GOOGLE_SEARCH_CX`,
      100 free queries/day) across `research`, `news`, and `affiliate-matches`.
      Since that quota is shared across every user, added a real async queue:
      `ai_request_queue` table (RLS, own-rows-only), `process-ai-queue` edge
      function (claims + processes one pending row per call), driven by a
      `pg_cron` schedule every 2 minutes (migrations `0003`/`0004`). Verified
      end-to-end: inserted a test row directly, confirmed `pg_cron` picked it
      up and `process-ai-queue` claimed/processed it within one tick. Client
      side: `AiQueueService.enqueueAndWait` inserts a row and awaits it via
      Supabase Realtime (no polling); `DriveResearchService`/`DriveNewsService`/
      `DriveAffiliateService` all go through it, cache-first via `IdeaCache`.
      Research/News/For-you tabs now show a "you're in the queue" loading
      state instead of a plain spinner, and first app open shows a one-time,
      friendly explainer dialog (`lib/screens/home_screen.dart`) telling
      control-group testers why results aren't instant. Rebuilt and verified
      the signed release APK (`flutter clean` + build + 3-point verification:
      version, signature, and a `strings` grep on `libapp.so` confirming the
      new code is actually in the binary).

- [x] **Google Custom Search → Tavily (2026-08-13)**: a real user report
      ("added an idea 16 hours ago, still no research") led to discovering
      Google Custom Search was structurally broken for this project — its
      error flipped between `429 quota exceeded` and `403 does not have
      access` even well under the 100/day cap, so the free tier was
      effectively unusable, not just small. User has no budget at all (not
      even ~$5), which ruled out OpenRouter's `:online` models (briefly
      tried, reverted — pay-per-use, no free option). Replaced with Tavily
      (`_shared/tavily.ts`), which is purpose-built for LLM/RAG web search
      and has a genuinely free, no-card-required tier. Deploying and testing
      this live surfaced two more real, pre-existing bugs, both fixed:
      (1) `generationConfig` was nested inside `contents[0].parts[0]`
      instead of being a sibling of `contents` in both
      `research_logic.ts`/`affiliate_logic.ts`'s Gemini calls — silently
      never caught before because Google Search always failed first;
      (2) `gemini-2.5-flash` is blocked for this project/key even though
      still listed by the Models API ("no longer available to new users") —
      switched to the `gemini-flash-latest` alias, which tracks whatever
      Google currently recommends instead of a version that can be retired
      out from under a pinned key. Verified the full pipeline end-to-end
      three ways: a real Research report (kind `research`) and a real
      For-you match set (kind `affiliate`) both completed successfully with
      real cited sources; a `news` row was also left for the actual
      `pg_cron` schedule (not a manual trigger) to pick up on its own
      2-minute tick, confirming the whole path — cron → claim → Tavily →
      Gemini → queue result — works unattended, which is what actually
      matters for a control group nobody is babysitting.

### Blocked / in progress
- [x] Rotate the exposed Supabase service-role key + DB password — done.
- [x] Google Cloud Console: Drive API, `drive.file` scope, OAuth client IDs — done.
- [ ] iOS build — deferred by user choice ("Android first"); needs Xcode on
      macOS or a cloud Mac CI, not possible from this Linux machine.

### Needs user input / later
- [ ] Decide: graceful fallback for Research/News/For-you if Tavily's free
      tier is ever exhausted (currently surfaces as a "try again" error once
      the queued request actually runs and fails) — lower risk than the old
      Google Search situation since Tavily's free cap is much more generous,
      but not impossible with enough concurrent testers.
- [ ] AdMob integration (later milestone).
- [ ] Play Store account, store listing, data-safety form — see `RELEASE_CHECKLIST.md`.

## Notes / gotchas
- User's original idea ("link Gemini/Perplexity from the user's Google account") is **not possible**: Perplexity has no OAuth, and Gemini OAuth would use our project's quota, not the user's. Google login is used for **identity only**. (This is also why the later pivot away from Perplexity uses the developer's own shared free-tier keys rather than any form of account-linking.)
- `sb_secret_...` (service role) and the DB password were exposed in chat once — user must rotate them in the Supabase dashboard.
- Linux run requires patched `linux/CMakeLists.txt` (native_assets guard) + system deps (`clang`, `ninja-build`, GStreamer dev packages).

## Commands
```bash
export PATH="$HOME/flutter/flutter/bin:$HOME/.local/bin:$PATH"
flutter analyze && flutter test
flutter build linux --debug
supabase db push
supabase functions deploy research news affiliate-matches process-ai-queue --use-api
supabase secrets set TAVILY_API_KEY=... GEMINI_API_KEY=...
```
