## IdeaVault — Test Build 2

Capture business ideas, get AI research and matched tools, and follow related news — saved straight to your own Google Drive.

### What's new since Test Build 1
- **Research and For-you are actually working now.** They were broken in the first build — now they run through a queue (so a request can take a couple minutes if others are ahead of you, instead of failing outright).
- **You'll see a heads-up message the first time you open the app** explaining why results aren't instant — this isn't running on a big server budget, just my own free-tier setup.
- **Deleting an idea now properly cancels anything still processing for it**, instead of leaving a stray request behind.
- General bug fixes under the hood (a couple of real backend issues that were silently breaking things).

### How to install (Android)
1. Tap the `IdeaVault.apk` file below to download it.
2. Open the downloaded file. If Android blocks it, tap **Settings** in the popup and allow installs from this app (one-time step) — this is normal for apps outside the Play Store.
3. Tap **Install**, then open IdeaVault and sign in with Google.
4. If you already have Test Build 1 installed, this will update it in place — no need to uninstall first.

### What to test
- Sign in with Google
- Capture an idea (text, photo, voice note)
- Try Research, News, and "For you" — give it a couple minutes if you're not the first one testing
- Check the idea, favorite it, set a reminder
- Delete an idea and confirm nothing weird happens
- Settings → Delete account (only if you're done testing — this is permanent)

### Known limits in this build
- Results aren't instant — everyone's requests share one queue, processed one at a time, every ~2 minutes.
- iOS isn't available yet.

Found a bug or something confusing? Just message me directly.
