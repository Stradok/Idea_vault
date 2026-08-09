# IdeaVault — Play Store release checklist

Everything below is what's left between "code is ready" and "live on the Play
Store." Code-level items done during the production-readiness pass are marked
done; everything else needs your account/action.

**Current plan**: ship the signed APK directly to a control group first
(sideloaded, no Play Console needed yet), then move to Play Store once that's
validated. Sections 5/6 below (store listing, Play Console setup) apply once
you're ready for that step — not blocking the control-group test.

## 0. Security — do this first

- [x] **Rotate the Supabase service-role key and DB password.** Done —
      new keys issued, `.env`'s `SUPABASE_ANON_KEY` updated, and
      `research`/`news`/`delete-account` redeployed to pick up the new
      auto-injected `SUPABASE_SERVICE_ROLE_KEY`.

## 0.5. Architecture pivot (2026-08-09): Google-only auth + Drive storage

The app was rebuilt to sign in with Google only and store all idea data
(title, notes, photos, voice notes, cached research/affiliate results) in the
user's own Google Drive instead of Supabase Postgres/Storage. See
`README.md` for the new architecture and the Google Cloud Console setup this
requires. Concretely, still needed before this is testable end-to-end:

- [ ] Google Cloud Console: enable Drive API, add `drive.file` scope to the
      OAuth consent screen (Testing mode + test users covers the control
      group — no verification wait), create Web/Android OAuth client IDs.
- [ ] Set `GOOGLE_WEB_CLIENT_ID` in `.env` (currently blank — the app will
      show the "needs setup" screen until this is filled in).
- [ ] Confirm Supabase's Google provider Client ID matches the new Web OAuth
      client.
- [ ] **Destructive, needs your explicit go-ahead before running**: a
      migration to drop the now-unused `ideas`/`research_reports` tables and
      the `idea-media` storage bucket (data lives in Drive now). Not run yet.

## 1. Code-level (done in this pass)

- [x] Custom app icon + adaptive icon + splash screen (`assets/icon/`).
- [x] Fixed a startup crash: `.env` wasn't declared as a Flutter asset, so
      `dotenv.load` would throw before `runApp` on any real build. Now
      declared as an asset and wrapped in try/catch as defense in depth.
- [x] ~~Google OAuth deep-link redirect~~ — superseded by the native
      Google Sign-In + Drive pivot (§0.5); no longer used.
- [x] In-app account deletion (Settings → Delete account): deletes the Drive
      `IdeaVault` folder and revokes Google access first, then calls the
      `delete-account` edge function to remove the Supabase auth user —
      required by Play Store policy for any app with account creation.
- [x] `PRIVACY.md` / `TERMS.md` drafted, linked in-app from Settings.
- [x] Android release signing wired to `android/key.properties` (generated —
      see §2), `minifyEnabled`/`shrinkResources` turned on, `allowBackup=false`.
- [x] Local Android SDK + JDK installed on this machine and a signed release
      build produced to confirm the whole chain works.
- [x] Fixed two real build failures only a real release build surfaces:
      NDK version mismatch (plugins needed 27.0.12077973, project pinned an
      older one) and missing core library desugaring for
      `flutter_local_notifications`.
- [x] Fixed `minSdk`: Flutter's default (21) is below what the `record`
      plugin (voice notes) requires; bumped to 23 (Android 6.0, still near-100%
      device coverage).
- [x] Verified: `app-release.apk` signature matches the new upload keystore
      (not debug), and `app-release.aab` (the file Play Console actually wants)
      builds cleanly too.

## 2. Your release keystore — back this up now

A real upload keystore was generated at:

```
android/app/upload-keystore.jks
android/key.properties   (passwords — gitignored, never commit)
```

**Copy both files somewhere safe outside this machine** (password manager +
encrypted cloud backup). If you lose this keystore, you cannot publish updates
to the same Play Store listing ever again without going through Google's
account-recovery process. Losing it is one of the most common one-way doors in
mobile releases — treat it like a production credential.

## 3. Accounts you'll need

| Account | Cost | Used for |
|---|---|---|
| [Google Play Console](https://play.google.com/console) | $25 one-time | Publishing the Android app |
| [Apple Developer Program](https://developer.apple.com/programs/) | $99/year | iOS — deferred per your "Android first" choice |
| Perplexity API key | Pay-as-you-go | Powers the Research tab (`PERPLEXITY_API_KEY`) |
| Google AI Studio (Gemini) API key | Free tier available | Powers the Research tab (`GEMINI_API_KEY`) |

Without the Perplexity/Gemini keys, tapping "Research" on an idea will fail —
decide whether to get the keys before submitting, or ship v1 with News +
Capture only and add Research in an update.

## 4. Hosting the legal docs

Play Console requires a **public URL** for your privacy policy (not just an
in-app screen). Easiest path: enable GitHub Pages on this repo and point it at
`PRIVACY.md`, or paste the content into a free static host. Put that URL in:

- Play Console → App content → Privacy policy
- Play Console → Store listing

## 5. Store listing content (Play Console → Store presence)

- [ ] Short description (≤80 chars)
- [ ] Full description (≤4000 chars)
- [ ] App icon 512×512 (export `assets/icon/icon.png` at 512 or let the console
      downscale the 1024 you have)
- [ ] Feature graphic 1024×500
- [ ] At least 2 phone screenshots (min 320px, max 3840px on the long edge) —
      grab these from a real run of the app once you've done a smoke test
- [ ] Category (Business), tags
- [ ] Contact email (khawajaamman@gmail.com) and privacy policy URL

## 6. Play Console setup

- [ ] App content → **Data safety** form. Based on `PRIVACY.md`: collected data
      = email, user content (ideas/notes/photos/audio), no data sold, data
      deletable in-app, encrypted in transit. Fill the form using that as your
      source of truth.
- [ ] App content → **Content rating** questionnaire (this app has no
      violence/mature content — should land as "Everyone").
- [ ] App content → **Government apps**, **Ads** (declare "No ads" — sponsors
      are curated/static, not a third-party ad network), **Target audience**.
- [ ] Enroll in **Play App Signing** when prompted on first upload (Google
      keeps a copy of your signing key as a safety net against future loss of
      the upload key — still back up your own copy regardless).

## 7. Before you upload

```bash
export PATH="$HOME/flutter/flutter/bin:$HOME/.local/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
flutter analyze && flutter test
flutter build appbundle --release   # Play Store wants an .aab, not .apk
```

Upload the `.aab` from `build/app/outputs/bundle/release/app-release.aab` to a
Play Console **Internal testing** track first, install it on a real device via
the testing link, and click through the full golden path (sign up, capture an
idea with photo/voice, research, news, favorite, reminder, delete account)
before promoting to production.

## 8. Deferred (per your "Android first, iOS later" choice)

- [ ] iOS build needs Xcode on macOS (or a cloud Mac CI like Codemagic) — this
      Linux machine can't produce an IPA. `Info.plist` and the OAuth URL
      scheme are already prepared for when you get there.
- [ ] AdMob integration — curated sponsors table already works as the interim
      monetization path per `plan.md`.
