# IdeaVault — Play Store release checklist

Everything below is what's left between "code is ready" and "live on the Play
Store." Code-level items done during the production-readiness pass are marked
done; everything else needs your account/action.

## 0. Security — do this first

- [ ] **Rotate the Supabase service-role key and DB password.** `plan.md` notes
      these were pasted into a chat once. Go to Supabase dashboard → Project
      Settings → API → "Reset service_role key", and Settings → Database →
      "Reset database password". After rotating, re-run
      `supabase secrets set` for any function that used the old value (the
      `delete-account` function added in this pass uses the auto-injected
      `SUPABASE_SERVICE_ROLE_KEY`, so it'll pick up the new one automatically —
      just redeploy: `supabase functions deploy delete-account`).

## 1. Code-level (done in this pass)

- [x] Custom app icon + adaptive icon + splash screen (`assets/icon/`).
- [x] Fixed a startup crash: `.env` wasn't declared as a Flutter asset, so
      `dotenv.load` would throw before `runApp` on any real build. Now
      declared as an asset and wrapped in try/catch as defense in depth.
- [x] Google OAuth deep-link redirect (`io.supabase.ideavault://login-callback`)
      wired into `AndroidManifest.xml`, iOS `Info.plist`, and the sign-in call.
      **You still need to** add that URL to Supabase → Authentication → URL
      Configuration → Redirect URLs.
- [x] In-app account deletion (Settings → Delete account), backed by the new
      `delete-account` edge function — required by Play Store policy for any
      app with account creation.
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
