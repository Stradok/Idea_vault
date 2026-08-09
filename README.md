# IdeaVault

Capture business ideas, research them with live data, follow relevant news, and get matched sponsors — all synced to your account.

## Stack

- **App**: Flutter (`lib/`)
- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions)
- **Research**: Perplexity (live search) → Gemini (structured report)
- **News**: NewsAPI, GNews, Hacker News, Reddit + BM25 reranking
- **Ads**: curated `sponsors` table (AdMob planned)

## Setup

### 1. App configuration

Copy `.env.example` to `.env` and fill in your Supabase project values:

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=sb_publishable_...
```

### 2. Supabase database

Push the migration (tables, RLS, storage bucket, seed sponsors):

```
supabase link --project-ref <project-ref>
supabase db push
```

### 3. Edge functions

```
supabase functions deploy research news delete-account
supabase secrets set PERPLEXITY_API_KEY=... GEMINI_API_KEY=...
supabase secrets set NEWSAPI_KEY=... GNEWS_KEY=...   # optional; HN + Reddit work without keys
```

The `news` function works without any keys (Hacker News + Reddit are free APIs).
The `research` function needs `PERPLEXITY_API_KEY` and `GEMINI_API_KEY`.
The `delete-account` function (Settings → Delete account) needs no extra
secrets — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`
are auto-injected into every edge function by Supabase.

### 4. Google sign-in (optional)

1. Google Cloud Console → APIs & Services → OAuth consent screen → add test users.
2. Credentials → Create OAuth client ID → **Web application** (Supabase calls Google server-side, not a mobile/desktop client type).
3. Supabase dashboard → Authentication → Providers → Google → enable + paste Client ID/Secret.
4. Supabase dashboard → Authentication → URL Configuration → **Redirect URLs** → add:
   ```
   io.supabase.ideavault://login-callback
   ```
   This matches the custom URL scheme registered in `AndroidManifest.xml` and iOS `Info.plist`, which is how the OAuth browser flow hands control back to the app on mobile.

### 5. Run

```
flutter pub get
flutter run
```

## Architecture

- `lib/state/idea_vault.dart` — app state (ChangeNotifier): load/add/delete/favorite/reminders.
- `lib/services/` — Supabase-backed services: ideas, media uploads, research, news, sponsors.
- `lib/screens/` — auth, home, add-idea, idea-detail (Research / News / For-you tabs).
- `supabase/migrations/` — schema + RLS + seeds.
- `supabase/functions/` — `research` (Perplexity→Gemini RAG), `news` (multi-source + BM25).
- `supabase/functions/_shared/` — CORS + BM25 rank helpers.

## Security

- All `ideas`/`research_reports` are private per user (RLS enforced by `auth.uid()`).
- Media files live in a private bucket, one folder per user, served via short-lived signed URLs.
- API keys live only in edge-function secrets — never in the app.
- `.env` is gitignored; the anon/publishable key is the only key in the app.
