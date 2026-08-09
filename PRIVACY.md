# Privacy Policy

**Last updated: 2026-08-08**

IdeaVault ("we", "our", "the app") lets you capture business ideas, research them
with live data, follow relevant news, and see curated sponsor offers. This policy
explains what data we collect, why, and how it's protected.

## Data we collect

| Data | Why | Where it's stored |
|---|---|---|
| Email address | Account creation and sign-in | Supabase Auth |
| Password | Sign-in (never stored in plain text — hashed by Supabase Auth) | Supabase Auth |
| Google account info (name, email) — if you use Google sign-in | Sign-in | Supabase Auth |
| Idea titles and notes you write | The core feature — storing your ideas | Supabase Postgres, private to your account |
| Photos and voice recordings you attach to an idea | Let you attach media to an idea | Supabase Storage, private folder per account |
| Idea title/notes text | Sent to Perplexity and Google Gemini to generate a research report when you tap "Research" | Not stored by us beyond the generated report; see *Third-party processors* below |
| Reminder date/times you set | The reminder feature | Supabase Postgres |

We do not collect location data, contacts, or any device identifiers beyond what's
required for push/local notifications to work.

## How your data is protected

- All ideas, notes, media, and research reports are private to your account,
  enforced at the database level with Postgres Row Level Security — no other
  user, including us, can query another user's rows through the app's normal
  access path.
- Photos and voice notes live in a private storage bucket, one folder per user,
  and are only ever served back to you via short-lived signed URLs.
- Data is encrypted in transit (HTTPS/TLS) and at rest (Supabase-managed
  Postgres/Storage encryption).

## Third-party processors

| Service | What it receives | Purpose |
|---|---|---|
| Supabase | All account and idea data described above | Database, auth, file storage, backend functions |
| Perplexity AI | The text of your idea's title/notes | Live web research for the "Research" tab |
| Google Gemini | The Perplexity research context + your idea title | Turns raw research into a structured report |
| NewsAPI, GNews, Hacker News, Reddit | Your idea's category/title as a search query | Powers the "News" tab — no account data is sent |

None of these providers receive your email, password, or any identity that lets
them connect the request back to you personally — only the idea text itself is
sent for research/news queries.

We do not sell your data. We do not show third-party ad networks (sponsor
listings are a curated, static list — see below).

## Sponsors ("For you" tab)

The sponsor offers shown in the app are a fixed, curated list of business tools
(e.g. Shopify, Stripe) matched to your idea's category. No data about you is
shared with these companies — tapping a sponsor's link simply opens their public
website.

## Your rights

- **Access/export**: every idea you've created is visible in the app at any time.
- **Deletion**: you can permanently delete your account and all associated data
  (ideas, notes, photos, voice notes, research reports) at any time from
  **Settings → Delete account**. This is irreversible and takes effect
  immediately.
- **Correction**: you can edit or delete any idea directly in the app.

## Children's privacy

IdeaVault is not directed at children under 13, and we do not knowingly collect
data from them.

## Changes to this policy

If this policy changes materially, we'll update the "Last updated" date above
and, where required, notify you in-app.

## Contact

Questions about this policy or your data: **khawajaamman@gmail.com**
