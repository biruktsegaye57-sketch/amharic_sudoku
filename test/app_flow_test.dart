import 'dart:io';

import 'package:amharic_sudoku/app.dart';
import 'package:amharic_sudoku/data/puzzle_bank.dart';
import 'package:amharic_sudoku/data/settings.dart';
import 'package:amharic_sudoku/game/game_controller.dart';
import 'package:amharic_sudoku/game/game_session.dart';
import 'package:amharic_sudoku/screens/board/board_screen.dart';
import 'package:sudoku_core/sudoku_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpApp(WidgetTester tester,
    {Map<String, Object> prefs = const {},
    Size size = const Size(360, 800),
    bool skipSplash = true}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final bank = PuzzleBank.parse(File('assets/puzzles/bank.json').readAsStringSync());
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(sp),
      puzzleBankProvider.overrideWithValue(bank),
    ],
    child: const GeezSudokuApp(),
  ));
  await tester.pump();
  if (skipSplash) {
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  return ProviderScope.containerOf(tester.element(find.byType(GeezSudokuApp)));
}

Future<void> settle(WidgetTester t) async {
  for (int i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Solves the current puzzle by tapping cells and keys.
Future<void> solveByTapping(WidgetTester tester, ProviderContainer c) async {
  final s = c.read(gameProvider)!;
  for (int i = 0; i < s.size; i++) {
    if (s.values[i] != 0) continue;
    await tester.tap(find.byKey(ValueKey('cell-$i')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('key-${s.solutionAt(i)}')));
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  testWidgets('onboarding → first 4×4 → solve → word collected', (tester) async {
    final c = await pumpApp(tester, skipSplash: false);
    // Animated splash, then onboarding.
    expect(find.text('ግዕዝ ሱዶኩ'), findsOneWidget);
    expect(find.text('Find the hidden word.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text('Sudoku, with fidel.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('A word is waiting.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Have a hunch?'), findsOneWidget);
    await tester.tap(find.text('Start with 4 × 4'));
    await settle(tester);

    expect(find.text('4 × 4 • Easy'), findsOneWidget);
    expect(find.text('Food · Hidden word'), findsOneWidget);
    await solveByTapping(tester, c);

    expect(c.read(gameProvider)!.status, GameStatus.won);
    expect(find.text('4 × 4 • Complete'), findsOneWidget);
    expect(find.text('Your first little discovery'), findsOneWidget);
    expect(find.text('+10 coins'), findsOneWidget, reason: 'Easy win pays 10 coins');
    expect(find.text('Doro wat: chicken stew'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('Daily ፊደል'), findsOneWidget);
    expect(find.text('1 words'), findsOneWidget);

    await tester.tap(find.text('Collection'));
    await settle(tester);
    expect(find.text('1 word discovered'), findsOneWidget);

    await tester.tap(find.text('Statistics'));
    await settle(tester);
    expect(find.text('Last 20 solve times'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await settle(tester);
    expect(find.text('Daily calendar'), findsOneWidget);
  });

  testWidgets('9×9: mistakes, hints, guess sheet, pause, resume card', (tester) async {
    final c = await pumpApp(tester, prefs: {'settings.v1': '{"onboarded":true}'});
    await settle(tester);
    expect(find.text('Daily ፊደል'), findsOneWidget);

    await tester.tap(find.text('Play daily puzzle'));
    await settle(tester);
    expect(find.text('9 × 9 • Medium'), findsOneWidget);
    final s = c.read(gameProvider)!;

    // A wrong entry shows a mistake.
    final i = s.values.indexOf(0);
    await tester.tap(find.byKey(ValueKey('cell-$i')));
    await tester.pump();
    final wrong = s.solutionAt(i) % 9 + 1;
    await tester.tap(find.byKey(ValueKey('key-$wrong')));
    await settle(tester);
    expect(s.mistakes, 1);
    expect(find.text('ስህተት 1/3'), findsOneWidget);

    // Undo it, then use a hint: explain next step.
    await tester.tap(find.text('Undo'));
    await settle(tester);
    await tester.tap(find.text('Hint 3'));
    await settle(tester);
    expect(find.text('A little help'), findsOneWidget);
    await tester.tap(find.text('Explain next step'));
    await settle(tester);
    expect(find.text('Show me'), findsOneWidget);
    await tester.tap(find.text('Show me'));
    await settle(tester);
    expect(s.hintsLeft, 2);

    // Guess the word correctly.
    await tester.tap(find.text('Guess word 3'));
    await settle(tester);
    expect(find.text('Guess the word'), findsOneWidget);
    final word = s.config.word!.fidel;
    final sheet = find.byType(BottomSheet);
    for (final f in word) {
      await tester.tap(find.descendant(of: sheet, matching: find.text(f)).last);
      await tester.pump();
    }
    await tester.tap(find.text('Submit guess'));
    await settle(tester);
    expect(s.wordFound, isTrue);
    expect(find.text('Keep solving'), findsOneWidget);
    await tester.tap(find.text('Keep solving'));
    await settle(tester);
    expect(find.text('${s.config.word!.theme.label} · Word discovered'), findsOneWidget);

    // Pause conceals the board.
    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-0')), findsNothing);
    await tester.tap(find.text('Resume'));
    await settle(tester);

    // Leave: home shows the continue card.
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('Continue puzzle'), findsOneWidget);
  });

  testWidgets('every top-level screen renders in all three themes and at 320 px',
      (tester) async {
    for (final (theme, size) in [
      ('light', const Size(360, 800)),
      ('dark', const Size(360, 800)),
      ('parchment', const Size(360, 800)),
      ('light', const Size(320, 640)),
    ]) {
      await pumpApp(tester,
          size: size,
          prefs: {'settings.v1': '{"onboarded":true,"theme":"$theme"}'});
      await settle(tester);
      final router = tester.state<State>(find.byType(Navigator).first);
      expect(router, isNotNull);
      for (final route in [
        '/packs', '/packs/food', '/collection', '/learn', '/classic',
        '/settings', '/settings/appearance', '/shop', '/help', '/legal/privacy',
        '/lesson/vowels', '/lesson/vowels/quiz', '/lesson/vowels/done',
        '/daily', '/daily/trophies', '/daily/today', '/stats',
        '/stats/achievements', '/report/s9a',
      ]) {
        final ctx = tester.element(find.byType(Scaffold).first);
        GoRouterHelper(ctx).go(route);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$theme $size $route');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final (label, size) in [('320×640', Size(320, 640)), ('360×800', Size(360, 800))]) {
    testWidgets('boards of every size fit and play at $label', (tester) async {
      final c = await pumpApp(tester,
          size: size, prefs: {'settings.v1': '{"onboarded":true}'});
      await settle(tester);
      final bank = c.read(puzzleBankProvider);
      for (final gs in GridSize.values) {
        final cfg = bank.quick(size: gs, grade: DifficultyGrade.easy);
        GoRouterHelper(tester.element(find.byType(Scaffold).first))
            .push('/play', extra: PlayArgs.start(cfg));
        await settle(tester);
        expect(find.text('${gs.n} × ${gs.n} • Easy'), findsOneWidget);
        // Every cell and key is on screen and tappable.
        for (final k in [0, gs.n * gs.n - 1]) {
          expect(tester.getRect(find.byKey(ValueKey('cell-$k'))).bottom,
              lessThan(size.height));
        }
        expect(tester.getRect(find.byKey(const ValueKey('key-1'))).bottom,
            lessThan(size.height));
        await solveByTapping(tester, c);
        expect(c.read(gameProvider)!.status, GameStatus.won);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Home'));
        await settle(tester);
      }
    });
  }
}
