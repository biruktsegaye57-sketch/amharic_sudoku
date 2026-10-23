# Google Play release checklist — Ge’ez Sudoku 1.0.0

Package: `com.biruk.amharic_sudoku` (permanent after the first upload)

## 0. Before anything else

- [ ] Back up `~/upload-keystore.jks` and `android/key.properties` (e.g. password
      manager or a private cloud folder). Every future update must be signed with this key.
- [ ] Privacy policy is `docs/index.html`, served by GitHub Pages at
      https://biruktsegaye57-sketch.github.io/amharic_sudoku/ (repo Settings → Pages →
      branch `main`, folder `/docs`). Edit that file and push to update it.

## 1. Build

```sh
flutter test && (cd packages/sudoku_core && dart test)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

The "failed to strip debug symbols" warning is harmless here: it comes from the
missing Android cmdline-tools, and the native libraries are already stripped.

For every later upload, bump `version:` in `pubspec.yaml` first
(`1.0.0+1` → `1.0.1+2`; the number after `+` must always increase).

## 2. Play Console: create the app

play.google.com/console → Create app → name "Ge’ez Sudoku", default language
English (United States), **Game**, **Free**.

## 3. App content: suggested answers

These match what the app actually does (offline, no INTERNET permission in release).

| Section | Answer |
|---|---|
| Privacy policy | Your hosted URL |
| App access | All functionality is available without special access |
| Ads | **No**, the app does not contain ads |
| Content rating (IARC) | Category: Puzzle/Game. Answer **No** to violence, sexuality, language, gambling, drugs, user interaction/chat, sharing location, and digital purchases. Expected result: Everyone / PEGI 3 |
| Target audience | 13+ is simplest. Picking under-13 groups triggers Families policy review (allowed, but slower) |
| News app | No |
| Data safety | Does the app collect or share user data? **No**. (Data stored only on device doesn't count as "collected.") Encrypted in transit: not applicable. Deletion request: not applicable, no data collected |
| Government app | No |
| Financial features | None |
| Health | None |
| Advertising ID | No (the app doesn't use it) |

## 4. Store listing

Copy text from `LISTING.md`. Upload:
- Icon: `graphics/icon-512.png`
- Feature graphic: `graphics/feature-graphic-1024x500.png`
- Phone screenshots: `screenshots/*.png`

## 5. Testing track

- [ ] Testing → Closed testing → create track → upload `app-release.aab`
- [ ] Accept **Play App Signing** when prompted (Google holds the app signing key;
      yours is the upload key)
- [ ] Personal developer accounts created after Nov 2023: get **12+ testers opted in
      for 14 consecutive days** before applying for production access.
      Add their Gmail addresses to a tester list and send them the opt-in link.

## 6. Production

- [ ] Dashboard → Apply for production (answer the short questionnaire about testing)
- [ ] Production → Create release → reuse the same bundle → release notes from `LISTING.md`
- [ ] Choose countries (e.g. all, or start with Ethiopia + diaspora countries) → Review → Start rollout

## Later: turning on ads / purchases / Amharic UI

`lib/core/constants/features.dart` has `kMonetizationEnabled` and
`kAmharicUiEnabled`. They hide placeholder UI that would otherwise be rejected
(non-functional buttons). Before flipping either:
- Ads → integrate AdMob, add the INTERNET permission, update the Ads and Data safety
  declarations and the privacy policy.
- Purchases → integrate Play Billing and create the products in Play Console.
