# IdeaVault

Capture business ideas, research them with live data, follow relevant news, and get AI-matched tools — all saved to your own Google Drive.

## Stack

- **App**: Flutter (`lib/`)
- **Identity**: Google Sign-In (native), bridged into a Supabase session so edge functions can verify the caller
- **Storage**: the user's own Google Drive (`drive.file` scope) — every idea is a JSON file, photos/voice notes are separate files, all inside an `IdeaVault` folder the app creates
- **Backend**: Supabase Edge Functions only (no database/storage for idea data) — stateless proxies that hide the Google Search/Gemini API keys
- **Research**: Google Custom Search (live web results) → Gemini (structured report)
- **News**: NewsAPI, GNews, Google Search, Hacker News, Reddit + BM25 reranking
- **"For you" tab**: Google Custom Search → Gemini matches real tools/services to the specific idea, falling back to a curated `sponsors` table if the AI call fails
- **Queue**: Research/News/For-you requests are queued (`ai_request_queue` table) and processed one at a time by `process-ai-queue`, invoked every 2 minutes by `pg_cron` — this is deliberate, not a bug: Google Custom Search's free tier is 100 queries/day, shared across every user, so requests are spent one at a time instead of however many people happen to tap a tab at once. The client (`lib/services/ai_queue_service.dart`) inserts a row and waits on it via Supabase Realtime.

Why Drive instead of a database: the user's ideas, photos, and voice notes live in *their* Google Drive, not on our servers — we never see or store that content ourselves.

## Setup

### 1. App configuration

Copy `.env.example` to `.env` and fill in your Supabase project values plus the Google Web OAuth client ID (see step 3 below):

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...
GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

### 2. Supabase edge functions

No database migration needed for idea data anymore — Supabase only hosts the stateless functions and the `profiles`/`sponsors` tables (see `supabase/migrations/0001_init.sql`).

```
supabase link --project-ref <project-ref>
supabase db push
supabase functions deploy research news affiliate-matches delete-account process-ai-queue --use-api
supabase secrets set GOOGLE_SEARCH_API_KEY=... GOOGLE_SEARCH_CX=... GEMINI_API_KEY=...
supabase secrets set NEWSAPI_KEY=... GNEWS_KEY=...   # optional; HN + Reddit work without keys
supabase secrets set QUEUE_CRON_SECRET=...           # shared secret pg_cron sends to process-ai-queue
```

- `news` works without any keys (Hacker News + Reddit are free APIs); Google Search improves results but is optional there.
- `research` and `affiliate-matches` need `GOOGLE_SEARCH_API_KEY` + `GOOGLE_SEARCH_CX` (a Programmable Search Engine, 100 free queries/day) and `GEMINI_API_KEY`.
- `delete-account` needs no extra secrets — `SUPABASE_SERVICE_ROLE_KEY` is auto-injected.
- `process-ai-queue` has `verify_jwt = false` (see `supabase/config.toml`) and checks `QUEUE_CRON_SECRET` itself instead — only `pg_cron` should call it. The actual pg_cron schedule (`supabase/migrations/0004_ai_queue_cron.sql`) reads that same secret out of Supabase Vault under the name `queue_cron_secret`, set separately via `supabase db query --linked "select vault.create_secret('...', 'queue_cron_secret')"`.

### 3. Google Cloud Console (sign-in + Drive access)

1. **APIs & Services → Library** → enable the **Google Drive API**.
2. **APIs & Services → OAuth consent screen** → add scope
   `.../auth/drive.file`. Stay in **Testing** mode and add your control
   group's emails as test users — this works immediately, no need to wait
   for Google's verification (that's only required to open the app to the
   general public later).
3. **APIs & Services → Credentials → Create OAuth client ID**:
   - **Web application** — this is your `GOOGLE_WEB_CLIENT_ID` (used as
     `serverClientId` for `google_sign_in`, and must also be set as the
     Client ID in Supabase's Google provider below).
   - **Android** — package `com.ideavault.idea_vault` + your release
     keystore's SHA-1 (`keytool -list -v -keystore android/app/upload-keystore.jks`).
   - **iOS** — bundle ID (needed once iOS work resumes).
4. Supabase dashboard → **Authentication → Providers → Google** → enable,
   paste the **Web** client ID/secret. (No redirect URL setup needed —
   sign-in is native `google_sign_in`, not a browser redirect; the app calls
   `signInWithIdToken` directly.)

### 4. Run

```
flutter pub get
flutter run
```

## Architecture

- `lib/state/idea_vault.dart` — app state (ChangeNotifier): load/add/delete/favorite/reminders.
- `lib/services/auth_service.dart` — bridges native Google Sign-In (identity + Drive access) into a Supabase session.
- `lib/services/drive/drive_client.dart` — thin Drive v3 API wrapper: the `IdeaVault` folder, JSON file CRUD, quota check, local media cache.
- `lib/services/idea_store.dart` — `DriveIdeaStore` (ideas as Drive JSON files) also implements `IdeaCache` so research/affiliate results cache inside the idea's own file.
- `lib/services/media_service.dart` — `DriveMediaService`: photos/voice notes as Drive files, downloaded once and cached locally for display (Drive has no signed-URL equivalent for private files).
- `lib/services/research_service.dart`, `affiliate_service.dart`, `news_service.dart` — Drive-cached implementations that go through `AiQueueService` instead of calling the edge functions directly.
- `lib/services/ai_queue_service.dart` — inserts a row into `ai_request_queue` and awaits its result via Supabase Realtime (no polling).
- `lib/screens/` — auth (Google-only), home (shows a one-time queue-explainer dialog), add-idea, idea-detail (Research / News / For-you tabs, each showing a "you're in the queue" state), settings (legal docs, delete account).
- `supabase/functions/_shared/research_logic.ts`, `news_logic.ts`, `affiliate_logic.ts` — the actual Google Search→Gemini pipelines, shared between the direct HTTP endpoints and the queue processor so there's one implementation.
- `supabase/functions/` — `research`/`news`/`affiliate-matches` (thin HTTP wrappers, kept for debugging — the app queues instead), `process-ai-queue` (claims and processes one pending queue row per invocation, run by `pg_cron`), `delete-account`.
- `supabase/functions/_shared/` — CORS, BM25 rank helpers, `google_search.ts` (Custom Search JSON API wrapper).
- `supabase/migrations/0003_ai_request_queue.sql`, `0004_ai_queue_cron.sql` — the queue table + RLS, and the `pg_cron` schedule that drives `process-ai-queue` every 2 minutes.

## Security

- Idea content (title, notes, photos, voice notes, cached AI results) lives entirely in the signed-in user's own Google Drive, in a folder only this app can access (`drive.file` scope — least privilege, not full Drive access).
- The Supabase session (from `signInWithIdToken`) is only used to authenticate calls to the stateless edge functions — no idea data passes through or is stored in Supabase.
- API keys (Google Search, Gemini, NewsAPI, GNews) live only in edge-function secrets — never in the app.
- `.env` is gitignored; the anon/publishable key and Google Web client ID are the only identifiers in the app — no secrets.
