# Ludo Royale (Flutter)

Pass & Play (2-4) + vs Computer, Ludo King rules, procedural sounds, AdMob (banner / interstitial / rewarded).
Local Wi-Fi multiplayer is NOT included (Pass & Play + AI were prioritised).

## Build APK + AAB with GitHub Actions (no PC)
1. Create a GitHub repo and upload this whole folder (phone browser: "Add file > Upload files"; keep the `.github` folder).
2. Edit `.github/workflows/build.yml`: change `--org com.yourcompany` to your own id (e.g. `com.acme`).
   The final package name is `<org>.ludo_royale` and cannot change after your first Play upload.
3. Repo > Actions > "Build Android (APK + AAB)" > Run workflow. After ~6-8 min, download the
   `ludo-royale-release` artifact: `app-release.apk` (install/test) and `app-release.aab` (Play Store).
   Without signing secrets the build is signed with the debug key - fine for testing, NOT for the Play Store.

## Signing for the Play Store
1. Actions > "Generate upload keystore" > Run workflow, enter a password + alias. Download the artifact
   (`upload-keystore.jks`, `keystore.b64`), then delete the run. Keep the .jks backed up safely.
2. Repo > Settings > Secrets and variables > Actions, add:
   `KEYSTORE_BASE64` (contents of keystore.b64), `KEYSTORE_PASSWORD`, `KEY_PASSWORD` (same password), `KEY_ALIAS`.
3. Re-run the build workflow: the AAB is now signed with your upload key.

## Going live with real ads
- `lib/services/ad_manager.dart`: set `useTestAds = false` and paste your 6 ad unit IDs (marked STEP 1 / STEP 2).
- Add secret `ADMOB_APP_ID` (your `ca-app-pub-...~...` app id) or edit it in `tools/patch_android.py` (STEP 3).
- Never click your own live ads. Add a privacy policy + (for EU/UK) a consent form via AdMob's UMP before release.
