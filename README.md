# Ge’ez Sudoku (amharic_sudoku)

Sudoku played with Amharic fidel. One solved row spells a hidden word; guess it
early for a bonus. Android-first Flutter app built to the Figma
"Ge’ez Sudoku — Product Design" file (Light, Dark and Parchment themes).

## Layout

- `packages/sudoku_core` — pure Dart engine: bitmask solver, generator,
  technique grader / hint finder, word placement, fidel data.
- `assets/puzzles/bank.json` — 2,440 pre-generated puzzles (4×4: 60, 6×6: 150,
  9×9: 400 per grade), each unique, graded by technique, no duplicates after
  relabelling. When a grade runs out, the app serves transformed copies
  (row/column/band swaps, transpose, relabel) with the same difficulty.
- `assets/words/words.json` — the hidden-word data source (see below).
  Regenerate: `cd packages/sudoku_core && dart run tool/generate_bank.dart ../../assets/puzzles/bank.json`
- `lib/` — app: `game/` (session, controller), `data/` (settings, progress,
  bank), `screens/` (one folder per area), `widgets/` (design-system pieces).

## Words

`assets/words/words.json` is the single source of truth: word, theme, English
and Amharic meaning, source note, review status, reviewers and a `disabled`
kill switch. The app plays only words that pass the word rules and are not
disabled. Rules (from the requirements, enforced in `sudoku_core` and tests):
4, 6 or 9 distinct fidel; no two fidel from one family; no homophones mixed
(ሀ/ሐ/ኀ/ኸ, ሰ/ሠ, አ/ዐ, ጸ/ፀ); each look-alike pair (ሰ/ሸ, ተ/ቸ, ነ/ኘ, ከ/ኸ, በ/ቨ)
raises the puzzle one difficulty step.

```sh
cd packages/sudoku_core
dart run tool/words.dart validate   ../../assets/words/words.json
dart run tool/words.dart export-csv ../../assets/words/words.json review.csv   # for reviewers
dart run tool/words.dart import-csv ../../assets/words/words.json review.csv   # merge back
```

A word becomes `approved` after two native-speaker reviewers sign off.

## Sound

Sound effects are synthesised (no third-party audio): plucked-string notes in
the Ethiopian tizita pentatonic. Regenerate with
`python3 tool/sounds/make_sounds.py android/app/src/main/res/raw`. They play
through a native `SoundPool` (`geez_sudoku/audio` channel in MainActivity.kt).
Pronunciation uses Android text-to-speech: an Amharic voice when installed,
otherwise an English voice reading a close romanisation.

## Build & test

```sh
flutter pub get
flutter test                                  # app + UI flow tests
(cd packages/sudoku_core && dart test)        # engine tests
flutter build apk --release --split-per-abi   # ~11 MB per-device APKs
flutter build apk --release                   # universal APK (all ABIs)
```

Screens can be rendered for design review:
`CAPTURE_DIR=/tmp/shots flutter test test/screens/capture_test.dart`.

## Not yet integrated

AdMob, Firebase (Analytics, Crashlytics, Remote Config), in-app purchases,
recorded pronunciation, Play Games leaderboards and the Amharic UI language.
Their entry points (shop, rewarded ads, language picker) are hidden by the flags
in `lib/core/constants/features.dart`.

## Releasing

Release builds are signed with the upload key from `android/key.properties`
(git-ignored; falls back to the debug key if absent). Store listing text,
graphics, screenshots and the Play Console checklist are in `play_store/`; the
privacy policy is `docs/index.html` (GitHub Pages). Build with `flutter build appbundle --release`.
