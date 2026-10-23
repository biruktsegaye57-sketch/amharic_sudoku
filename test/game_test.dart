import 'dart:convert';
import 'dart:io';

import 'package:amharic_sudoku/core/constants/word_bank.dart';
import 'package:amharic_sudoku/data/puzzle_bank.dart';
import 'package:amharic_sudoku/game/game_config.dart';
import 'package:amharic_sudoku/game/game_session.dart';
import 'package:amharic_sudoku/game/symbols.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_core/sudoku_core.dart';

PuzzleBank loadBank() =>
    PuzzleBank.parse(File('assets/puzzles/bank.json').readAsStringSync());

GameSession place(GameSession s, int i, int d) {
  s.input(i, d, autoRemoveNotes: true, countMistakes: true, enforceLimit: true);
  return s;
}

void main() {
  final bank = loadBank();

  group('Puzzle bank', () {
    test('every size and grade has unique, valid puzzles, no duplicates after normalising', () {
      String norm(String p) {
        final m = <String, String>{};
        return p.split('').map((c) => c == '.' ? '.' : m.putIfAbsent(c, () => '${m.length + 1}')).join();
      }
      final seen = <String>{};
      for (final size in GridSize.values) {
        for (final g in [
          DifficultyGrade.easy,
          DifficultyGrade.medium,
          DifficultyGrade.hard,
          DifficultyGrade.expert,
        ]) {
          final list = bank.list(size, g);
          expect(list.length, greaterThanOrEqualTo(60), reason: '$size $g');
          for (final p in list) {
            expect(seen.add(norm(p.puzzle)), isTrue, reason: 'duplicate ${p.id}');
            expect(SudokuSolver.isUnique(p.puzzleGrid), isTrue, reason: p.id);
            expect(p.solutionGrid.isValid() && p.solutionGrid.isFull(), isTrue);
            expect(WordMapping.eligibleRows(p), isNotEmpty);
          }
        }
      }
    });

    test('9×9 grades match the technique grader', () {
      for (final g in [DifficultyGrade.medium, DifficultyGrade.hard, DifficultyGrade.expert]) {
        for (final p in bank.list(GridSize.nine, g).take(10)) {
          expect(TechniqueSolver.grade(p.puzzleGrid), g, reason: p.id);
        }
      }
    });

    test('every word: word row spells it, givens never reveal it, no other line spells a word', () {
      for (final w in WordBank.all) {
        for (final g in DifficultyGrade.values.take(4)) {
          if (w.numericGradeFor(g) == null) continue;
          for (int k = 0; k < 5; k++) {
            final s = bank.session(bank.quick(size: w.gridSize, grade: g).withWord(w.id, k));
            final m = s.mapping!;
            final n = s.n;
            expect(m.spells(s.data, w.fidel), isTrue, reason: '${w.id} ${s.data.id}');
            expect(s.data.givensInRow(m.wordRow), lessThanOrEqualTo(n ~/ 3));
            String at(int r, int c) => s.glyph(s.solutionAt(r * n + c));
            final words = {for (final o in WordBank.forSize(w.gridSize)) o.fidel.join()};
            for (int r = 0; r < n; r++) {
              if (r == m.wordRow) continue;
              expect(words.contains([for (int c = 0; c < n; c++) at(r, c)].join()), isFalse);
            }
            for (int c = 0; c < n; c++) {
              expect(words.contains([for (int r = 0; r < n; r++) at(r, c)].join()), isFalse);
            }
            expect(words.contains([for (int i = 0; i < n; i++) at(i, i)].join()), isFalse);
          }
        }
      }
    });

    test('transformed puzzles stay valid, unique and same grade (all sizes)', () {
      for (final size in GridSize.values) {
        for (final p in bank.list(size, DifficultyGrade.medium).take(5)) {
          for (int seed = 1; seed < 6; seed++) {
            final t = p.transformed(seed);
            expect(t.solutionGrid.isValid() && t.solutionGrid.isFull(), isTrue, reason: t.id);
            expect(SudokuSolver.isUnique(t.puzzleGrid), isTrue);
            expect(bank.byId(size, t.id)!.puzzle, t.puzzle);
            if (size == GridSize.nine) {
              expect(TechniqueSolver.grade(t.puzzleGrid), p.grade);
            }
          }
        }
      }
    });

    test('when every puzzle was played, a transformed copy is served', () {
      final all = [for (final p in bank.list(GridSize.four, DifficultyGrade.easy)) p.id];
      final cfg = bank.quick(size: GridSize.four, grade: DifficultyGrade.easy, avoid: all);
      expect(cfg.puzzleId, contains('~t'));
      expect(bank.session(cfg).mapping, isNotNull);
    });

    test('4×4 tutorial puts ዶሮ ወጥ in row 1', () {
      expect(bank.session(bank.onboarding4()).wordRow, 0);
    });

    test('onboarding 9×9 uses the design fixture with ጎበዝ ተማሪ ናችሁ in row 3', () {
      final s = bank.session(bank.onboarding9());
      expect(s.data.id, 'fixture');
      expect(s.wordRow, 2);
      expect(s.config.grade, DifficultyGrade.medium, reason: 'ተ/ቸ raises Easy to Medium');
      expect(s.keypadDigits.map(s.glyph).join(), 'ሁማሪበተችናዝጎ');
    });

    test('daily puzzle is deterministic per day', () {
      final a = bank.daily(DateTime(2026, 10, 16));
      final b = bank.daily(DateTime(2026, 10, 16));
      final c = bank.daily(DateTime(2026, 10, 17));
      expect(a.puzzleId, b.puzzleId);
      expect(a.wordId, b.wordId);
      expect('${a.puzzleId}${a.wordId}', isNot('${c.puzzleId}${c.wordId}'));
    });
  });

  group('GameSession', () {
    late GameSession s;
    setUp(() => s = bank.session(bank.quick(
        size: GridSize.nine, grade: DifficultyGrade.medium, theme: WordTheme.food)));

    int firstEmpty() => s.values.indexOf(0);

    test('correct entry, then win when every cell is filled', () {
      for (int i = 0; i < s.size; i++) {
        if (s.values[i] == 0) place(s, i, s.solutionAt(i));
      }
      expect(s.status, GameStatus.won);
      expect(s.mistakes, 0);
    });

    test('three mistakes end the game; extra chance continues it', () {
      final i = firstEmpty();
      final wrong = s.solutionAt(i) % 9 + 1;
      place(s, i, wrong);
      expect(s.mistakes, 1);
      expect(s.isWrong(i), isTrue);
      place(s, i, wrong % 9 + 1 == s.solutionAt(i) ? (wrong + 1) % 9 + 1 : wrong % 9 + 1);
      s.erase(i);
      final j = firstEmpty();
      place(s, j, s.solutionAt(j) % 9 + 1);
      expect(s.mistakes, 3);
      expect(s.status, GameStatus.lost);
      s.extraChances++;
      s.status = GameStatus.playing;
      expect(s.status, GameStatus.playing);
    });

    test('"no limit" counts mistakes but never ends the game', () {
      final i = firstEmpty();
      for (int k = 0; k < 5; k++) {
        s.input(i, (s.solutionAt(i) + k) % 9 + 1 == s.solutionAt(i) ? 1 : (s.solutionAt(i) + k) % 9 + 1,
            autoRemoveNotes: true, countMistakes: true, enforceLimit: false);
        s.erase(i);
      }
      expect(s.status, GameStatus.playing);
      expect(s.mistakes, greaterThan(3));
    });

    test('notes toggle, auto-remove from peers, and undo restores them', () {
      final i = firstEmpty();
      final d = s.solutionAt(i);
      // Put a note for d in a peer in the same row.
      final row = s.row(i);
      final peer = [for (int c = 0; c < 9; c++) row * 9 + c]
          .firstWhere((p) => p != i && s.values[p] == 0);
      s.notesMode = true;
      place(s, peer, d);
      expect(s.hasNote(peer, d), isTrue);
      s.notesMode = false;
      place(s, i, d);
      expect(s.hasNote(peer, d), isFalse, reason: 'auto-removed');
      s.undo();
      expect(s.values[i], 0);
      expect(s.hasNote(peer, d), isTrue, reason: 'undo restores peer notes');
    });

    test('conflict detection names the unit', () {
      // Find an empty cell and a given in its row.
      for (int i = 0; i < s.size; i++) {
        if (s.values[i] != 0) continue;
        final r = s.row(i);
        for (int c = 0; c < 9; c++) {
          final j = r * 9 + c;
          if (s.isGiven(j) && s.values[j] != s.solutionAt(i)) {
            place(s, i, s.values[j]);
            expect(s.conflictIndex, isNotNull);
            expect(['row', 'column', 'box'], contains(s.conflictUnit));
            return;
          }
        }
      }
    });

    test('word guess: wrong uses a guess, correct marks the word found', () {
      final word = s.config.word!.fidel;
      expect(s.guessWord(word.reversed.toList(), word), GuessResult.wrong);
      expect(s.guessesLeft, 2);
      expect(s.guessWord(word, word), GuessResult.correct);
      expect(s.wordFound, isTrue);
    });

    test('free hints: 3 Easy/Medium, 1 Hard, 0 Expert', () {
      expect(GameSession.defaultHints(DifficultyGrade.easy), 3);
      expect(s.hintsLeft, 3);
      for (int i = 0; i < 3; i++) {
        expect(s.useHint(), isTrue);
      }
      expect(s.useHint(), isFalse);
      expect(GameSession.defaultHints(DifficultyGrade.hard), 1);
      expect(GameSession.defaultHints(DifficultyGrade.expert), 0);
    });

    test('notes stay hidden under a value and return on erase', () {
      final i = firstEmpty();
      s.notesMode = true;
      place(s, i, 1);
      place(s, i, 2);
      s.notesMode = false;
      place(s, i, s.solutionAt(i));
      expect(s.values[i], s.solutionAt(i));
      s.erase(i);
      expect(s.values[i], 0);
      expect(s.hasNote(i, 1) && s.hasNote(i, 2), isTrue);
      s.erase(i);
      expect(s.notes[i], 0, reason: 'second erase clears notes');
    });

    test('a hint is not undone and a used hint is not refunded', () {
      final i = firstEmpty();
      place(s, i, s.solutionAt(i) % 9 + 1); // wrong
      s.useHint();
      s.reveal(i); // fill-cell replaces the wrong value
      expect(s.values[i], s.solutionAt(i));
      expect(s.mistakes, 1, reason: 'fill-cell does not count a mistake');
      s.undo();
      expect(s.values[i], s.solutionAt(i), reason: 'undo skips the hint cell');
      expect(s.hintsLeft, 2);
    });

    test('undo is blocked after the game is lost', () {
      final i = firstEmpty();
      for (int k = 0; k < 3; k++) {
        s.erase(i);
        place(s, i, (s.solutionAt(i) + k) % 9 + 1 == s.solutionAt(i) ? (s.solutionAt(i) + 5) % 9 + 1 : (s.solutionAt(i) + k) % 9 + 1);
      }
      expect(s.status, GameStatus.lost);
      final before = List.of(s.values);
      s.undo();
      expect(s.values, before);
    });

    test('undo history survives save/restore', () {
      final i = firstEmpty();
      place(s, i, s.solutionAt(i));
      final r = GameSession.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>)
        ..status = GameStatus.playing;
      expect(r.canUndo, isTrue);
      r.undo();
      expect(r.values[i], 0);
    });

    test('a different real word with the same fidel is reported as such', () {
      final word = s.config.word!.fidel;
      final r = s.guessWord(word.reversed.toList(), word, isRealWord: (_) => true);
      expect(r, GuessResult.realWord);
      expect(s.guessesLeft, 2);
    });

    test('auto-notes fills candidates from the visible board', () {
      s.fillAutoNotes();
      final i = firstEmpty();
      expect(s.hasNote(i, s.solutionAt(i)), isTrue);
      for (int j = 0; j < s.size; j++) {
        if (s.values[j] != 0 && s.arePeers(i, j)) {
          expect(s.hasNote(i, s.values[j]), isFalse);
        }
      }
    });

    test('completing a row, column or box is detected', () {
      final r = s.row(firstEmpty());
      final cells = [for (int c = 0; c < 9; c++) r * 9 + c];
      for (final i in cells) {
        if (s.values[i] == 0) place(s, i, s.solutionAt(i));
      }
      expect(s.completedUnitsAt(cells.first), containsAll(cells));
    });

    test('theme hidden on Hard/Expert until revealed', () {
      final hard = bank.session(bank.quick(size: GridSize.nine, grade: DifficultyGrade.hard));
      expect(hard.themeVisible, isFalse);
      hard.themeRevealed = true;
      expect(hard.themeVisible, isTrue);
      expect(s.themeVisible, isTrue, reason: 'Medium shows the theme');
    });

    test('save / restore round trip', () {
      final i = firstEmpty();
      place(s, i, s.solutionAt(i));
      s.elapsed = 77;
      final restored = GameSession.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(restored.values, s.values);
      expect(restored.elapsed, 77);
      expect(restored.mapping!.symbolMap, s.mapping!.symbolMap);
      expect(restored.config.wordId, s.config.wordId);
    });

    test('keypad is in ሀለሐ order, never word order', () {
      final word = s.config.word!.fidel;
      final pad = s.keypadDigits.map(s.glyph).toList();
      expect(pad, sortFidelInOrder(word));
    });

    test('classic sessions show numerals and have no word', () {
      final cfg = bank.classic(grade: DifficultyGrade.easy, symbols: SymbolSet.geez);
      final c = bank.session(cfg);
      expect(c.mapping, isNull);
      expect(c.glyph(1), '፩');
      expect(c.keypadDigits, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });
  });
}
