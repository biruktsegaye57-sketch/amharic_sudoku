// Renders app screens to PNG for visual comparison with the Figma frames.
//
//   CAPTURE_DIR=/some/dir flutter test test/screens/capture_test.dart
//
// Skipped unless CAPTURE_DIR is set.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:amharic_sudoku/app.dart';
import 'package:amharic_sudoku/core/constants/word_bank.dart';
import 'package:amharic_sudoku/core/utils/ethiopic_calendar.dart';
import 'package:amharic_sudoku/data/puzzle_bank.dart';
import 'package:amharic_sudoku/data/settings.dart';
import 'package:amharic_sudoku/game/game_config.dart';
import 'package:amharic_sudoku/game/game_controller.dart';
import 'package:amharic_sudoku/screens/board/board_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_core/sudoku_core.dart';

final _dir = Platform.environment['CAPTURE_DIR'];
final _shot = GlobalKey();

/// Design fixture: 9 × 9, word row 3 = ጎበዝ ተማሪ ናችሁ.
GameConfig fixture(DifficultyGrade g) => GameConfig(
      size: GridSize.nine,
      grade: g,
      puzzleId: 'fixture',
      symbols: SymbolSet.fidel,
      source: PuzzleSource.quick,
      wordId: 's9a',
      wordRow: 2,
    );

Map<String, Object> seededPrefs({String theme = 'light'}) {
  final now = DateTime.now();
  final eth = EthiopicDate.fromGregorian(now);
  final first = eth.firstOfMonth.toGregorian();
  final daily = <String, dynamic>{};
  final records = <Map<String, dynamic>>[];
  for (int d = 0; d < eth.day - 1; d++) {
    if (d == 3) continue; // one missed day
    final day = first.add(Duration(days: d));
    daily[dayKey(day)] = {'w': 's9a', 's': 400 + d * 7};
    records.add({
      'b': '9', 'g': 'medium', 'w': true, 's': 300 + (d * 37) % 400, 'm': d % 2,
      'h': 0, 'iw': true, 'ge': d.isEven, 'd': day.add(const Duration(hours: 12)).millisecondsSinceEpoch,
    });
  }
  final collection = {
    for (final (i, id) in ['s9a', 'f6a', 'f4a', 'c4a', 'h4b'].indexed)
      id: {
        'id': id,
        'd': now.subtract(Duration(days: i + 1)).millisecondsSinceEpoch,
        'sz': id.contains('9') ? 'nine' : id.contains('6') ? 'six' : 'four',
        'g': 'medium', 's': 517, 'm': 1, 'h': 0, 'ge': i.isEven,
      },
  };
  return {
    'settings.v1': jsonEncode({'onboarded': true, 'theme': theme}),
    'progress.v1': jsonEncode({
      'records': records,
      'collection': collection,
      'daily': daily,
      'coins': 150,
      'lessons': {'vowels': 'started'},
      'rateShown': true,
    }),
  };
}

Future<ProviderContainer> pump(WidgetTester tester, Map<String, Object> prefs,
    {Size size = const Size(360, 800)}) async {
  await tester.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final bank = PuzzleBank.parse(File('assets/puzzles/bank.json').readAsStringSync());
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  final skipSplash = prefs.isNotEmpty;
  await tester.pumpWidget(RepaintBoundary(
    key: _shot,
    child: ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(sp),
        puzzleBankProvider.overrideWithValue(bank),
      ],
      child: const GeezSudokuApp(),
    ),
  ));
  if (skipSplash) await tester.pump(const Duration(milliseconds: 2600));
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(GeezSudokuApp)));
}

Future<void> settle(WidgetTester t, [int frames = 8]) async {
  for (int i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> snap(WidgetTester tester, String name) async {
  await settle(tester, 4);
  final boundary = _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

BuildContext ctx(WidgetTester t) => t.element(find.byType(Scaffold).last);
void go(WidgetTester t, String r) => GoRouter.of(ctx(t)).go(r);
void push(WidgetTester t, String r, {Object? extra}) =>
    GoRouter.of(ctx(t)).push(r, extra: extra);

Future<void> tapText(WidgetTester t, String s) async {
  await t.tap(find.text(s).last);
  await settle(t);
}

Future<void> tapCell(WidgetTester t, int i) async {
  await t.tap(find.byKey(ValueKey('cell-$i')));
  await t.pump();
}

Future<void> tapKey(WidgetTester t, int d) async {
  await t.tap(find.byKey(ValueKey('key-$d')));
  await t.pump();
}

void main() {
  if (_dir == null) {
    test('capture skipped (set CAPTURE_DIR)', () {});
    return;
  }
  Directory(_dir!).createSync(recursive: true);

  testWidgets('onboarding', (t) async {
    await pump(t, {});
    await snap(t, '00_splash_a'); // ~0.8 s: tiles popping in
    await t.pump(const Duration(milliseconds: 500));
    await snap(t, '00_splash_b'); // ~1.3 s: gold sweep
    await t.pump(const Duration(milliseconds: 500));
    await snap(t, '01_splash'); // ~1.8 s: complete
    await t.pump(const Duration(seconds: 2));
    await settle(t);
    await snap(t, '02_rules');
    await tapText(t, 'Next');
    await snap(t, '03_hidden');
    await tapText(t, 'Next');
    await snap(t, '04_guess_early');
  });

  testWidgets('home variants and new puzzle sheet', (t) async {
    await pump(t, {'settings.v1': '{"onboarded":true}'});
    await snap(t, '05_home_first');
    final c = await pump(t, seededPrefs());
    final bank = c.read(puzzleBankProvider);
    push(t, '/play', extra: PlayArgs.start(bank.quick(size: GridSize.six, grade: DifficultyGrade.medium)));
    await settle(t);
    await t.tap(find.byTooltip('Back'));
    await settle(t);
    await snap(t, '06_home_returning');
    await tapText(t, 'New puzzle');
    await tapText(t, 'Start new');
    await snap(t, '07_new_puzzle_sheet');
  });

  testWidgets('9×9 board states', (t) async {
    final c = await pump(t, seededPrefs());
    final ctrl = c.read(gameProvider.notifier);
    push(t, '/play', extra: PlayArgs.start(fixture(DifficultyGrade.medium)));
    await settle(t);
    await snap(t, '08_board_fresh');
    await tapCell(t, 18);
    await snap(t, '10_board_selected');
    await tapKey(t, 9); // ብ already in row 3
    await settle(t);
    await snap(t, '12_board_mistake');
    ctrl.undo();
    await settle(t);
    // Correct entries as in the design: ተ at R3C4, ሪ at R3C6.
    await tapCell(t, 21);
    await tapKey(t, 3);
    await tapCell(t, 23);
    await tapKey(t, 2);
    await tapCell(t, 40);
    await settle(t);
    await snap(t, '11_board_entries');
    await tapText(t, 'Notes');
    await tapCell(t, 2);
    await tapKey(t, 4);
    await tapKey(t, 6);
    await tapKey(t, 2);
    await snap(t, '13_board_notes');
    await tapText(t, 'Notes ON');
    await tapText(t, 'Guess word 3');
    for (final f in ['ጎ', 'በ']) {
      await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(f)).last);
      await t.pump();
    }
    await snap(t, '14_guess_partial');
    for (final f in ['ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ሁ', 'ች']) {
      await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(f)).last);
      await t.pump();
    }
    await tapText(t, 'Submit guess');
    await snap(t, '15_guess_wrong');
    await t.tap(find.byTooltip('Remove last letter'));
    await settle(t);
    for (final f in ['ጎ', 'በ', 'ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ች', 'ሁ']) {
      await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(f)).last);
      await t.pump();
    }
    await tapText(t, 'Submit guess');
    await snap(t, '16_guess_correct');
    await tapText(t, 'Keep solving');
    await snap(t, '17_board_guessed');
    await tapText(t, 'Hint 3');
    await snap(t, '18_hints_sheet');
    await tapText(t, 'Explain next step');
    await snap(t, '19_hint_explanation');
    await tapText(t, 'Got it');
    await t.tap(find.byTooltip('Pause'));
    await settle(t);
    await snap(t, '21_pause');
    await tapText(t, 'Restart');
    await snap(t, '52_restart_dialog');
    await tapText(t, 'Cancel');
    await tapText(t, 'Resume');
    final s = c.read(gameProvider)!;
    for (int i = 0; i < s.size; i++) {
      if (s.values[i] == 0) {
        await tapCell(t, i);
        await tapKey(t, s.solutionAt(i));
      }
    }
    await settle(t, 12);
    await snap(t, '22_solved_9');
  });

  testWidgets('easy band, game over, dark and parchment boards', (t) async {
    var c = await pump(t, seededPrefs());
    push(t, '/play', extra: PlayArgs.start(fixture(DifficultyGrade.easy)));
    await settle(t);
    await snap(t, '09_board_easy');
    final s = c.read(gameProvider)!;
    final empties = [for (int i = 0; i < s.size; i++) if (s.values[i] == 0) i];
    for (final i in empties.take(3)) {
      await tapCell(t, i);
      await tapKey(t, s.solutionAt(i) % 9 + 1);
    }
    await settle(t);
    await snap(t, '20_game_over');

    for (final theme in ['dark', 'parchment']) {
      c = await pump(t, seededPrefs(theme: theme));
      push(t, '/play', extra: PlayArgs.start(fixture(DifficultyGrade.medium)));
      await settle(t);
      await tapCell(t, 21);
      await tapKey(t, 3);
      await tapCell(t, 23);
      await tapKey(t, 2);
      await tapCell(t, 21);
      await snap(t, '50_board_$theme');
      go(t, '/');
      await settle(t);
      await snap(t, '51_home_$theme');
    }
  });

  testWidgets('small boards and classic', (t) async {
    final c = await pump(t, seededPrefs());
    final bank = c.read(puzzleBankProvider);
    for (final (name, cfg) in [
      ('23_fresh_4', bank.onboarding4()),
      ('25_fresh_6', bank.pack(WordBank.byId('f6a')!)),
    ]) {
      push(t, '/play', extra: PlayArgs.start(cfg));
      await settle(t);
      await snap(t, name);
      final s = c.read(gameProvider)!;
      for (int i = 0; i < s.size; i++) {
        if (s.values[i] == 0) {
          await tapCell(t, i);
          await tapKey(t, s.solutionAt(i));
        }
      }
      await settle(t, 12);
      await snap(t, name.replaceFirst('fresh', 'solved'));
      go(t, '/');
      await settle(t);
    }
    push(t, '/classic');
    await settle(t);
    await snap(t, '40_classic_setup');
    await tapText(t, 'Start classic puzzle');
    await snap(t, '41_classic_board');
  });

  testWidgets('daily, packs, collection, learn, stats, settings', (t) async {
    await pump(t, seededPrefs());
    for (final (name, route) in [
      ('26_daily_calendar', '/daily'),
      ('27_trophies', '/daily/trophies'),
      ('28_daily_done', '/daily/today'),
      ('29_packs', '/packs'),
      ('30_pack_food', '/packs/food'),
      ('31_collection', '/collection'),
      ('32_word_detail', '/collection/s9a'),
      ('33_learn', '/learn'),
      ('42_stats', '/stats'),
      ('43_achievements', '/stats/achievements'),
    ]) {
      go(t, route);
      await settle(t);
      await snap(t, name);
    }
    for (final (name, route) in [
      ('34_lesson', '/lesson/vowels'),
      ('35_quiz', '/lesson/vowels/quiz'),
      ('38_lesson_done', '/lesson/vowels/done'),
      ('44_shop', '/shop'),
      ('45_settings_gameplay', '/settings'),
      ('46_settings_appearance', '/settings/appearance'),
      ('47_how_to_play', '/help'),
      ('48_report', '/report/s9a'),
    ]) {
      push(t, route);
      await settle(t);
      await snap(t, name);
      if (name == '35_quiz') {
        await tapText(t, 'ቦ');
        await snap(t, '36_quiz_correct');
        await tapText(t, 'Continue');
        await tapText(t, 'ቢ');
        await snap(t, '37_quiz_wrong');
      }
      GoRouter.of(ctx(t)).pop();
      await settle(t);
    }
  });

  testWidgets('empty states', (t) async {
    await pump(t, {'settings.v1': '{"onboarded":true}'});
    for (final (name, route) in [
      ('39_collection_empty', '/collection'),
      ('49_stats_empty', '/stats'),
    ]) {
      go(t, route);
      await settle(t);
      await snap(t, name);
    }
  });
}
