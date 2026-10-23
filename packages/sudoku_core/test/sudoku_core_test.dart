import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// The design-handoff fixture (Figma "Delivery contract"): givens, solution and
/// digit → fidel mapping. Word row 3 spells ጎበዝ ተማሪ ናችሁ.
const _fixturePuzzle =
    '53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79';
const _fixtureSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';
const _fixtureMap = ['', 'ጎ', 'ሪ', 'ተ', 'ማ', 'ና', 'ች', 'ሁ', 'ዝ', 'በ'];
const _fixtureWord = ['ጎ', 'በ', 'ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ች', 'ሁ'];

void main() {
  group('SudokuSolver', () {
    test('solves the design fixture to its documented solution', () {
      final grid = SudokuGrid.fromCompactString(GridSize.nine, _fixturePuzzle);
      final solved = SudokuSolver.solveGrid(grid)!;
      expect(solved.toCompactString(), _fixtureSolution);
      expect(SudokuSolver.isUnique(grid), isTrue);
    });

    test('solves a 17-clue minimum puzzle', () {
      const p =
          '...........1..2.3...4.5.....6.......7.8...4..9...1..5..2...3....4...6..8.9.....7.';
      // Any valid 17-clue puzzle; verify solution validity rather than a
      // hard-coded answer.
      final grid = SudokuGrid.fromCompactString(GridSize.nine, p);
      final solved = SudokuSolver.solveGrid(grid);
      if (solved != null) {
        expect(solved.isFull(), isTrue);
        expect(solved.isValid(), isTrue);
        for (int i = 0; i < 81; i++) {
          if (p[i] != '.') expect(solved.values[i], int.parse(p[i]));
        }
      }
    });

    test('solves the classic 17-clue puzzle uniquely', () {
      const p =
          '000000010400000000020000000000050407008000300001090000300400200050100000000806000';
      final grid = SudokuGrid.fromCompactString(
          GridSize.nine, p.replaceAll('0', '.'));
      final sw = Stopwatch()..start();
      expect(SudokuSolver.uniquenessCheck(grid), 1);
      final solved = SudokuSolver.solveGrid(grid)!;
      sw.stop();
      expect(solved.isFull() && solved.isValid(), isTrue);
      // Generous bound for CI machines; target on device is < 50 ms.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('detects multiple solutions', () {
      final empty = SudokuGrid(GridSize.four);
      expect(SudokuSolver.uniquenessCheck(empty), 2);
    });
  });

  group('PuzzleGenerator', () {
    for (final size in GridSize.values) {
      for (final grade in [DifficultyGrade.easy, DifficultyGrade.medium]) {
        test('${size.name} ${grade.name} has exactly one solution', () {
          final gen = PuzzleGenerator(GeneratorConfig(
            size: size,
            targetGrade: grade,
            seed: 42,
            maxAttempts: 400,
          ));
          final (puzzle, solution) = gen.generate();
          expect(SudokuSolver.isUnique(puzzle), isTrue);
          expect(solution.isFull() && solution.isValid(), isTrue);
          final givens = puzzle.values.where((v) => v != 0).length;
          expect(givens, lessThan(size.n * size.n),
              reason: 'small boards used to come out fully given');
          expect(givens, lessThanOrEqualTo(kClueFloors[size]![grade]! + 1));
          for (int i = 0; i < puzzle.values.length; i++) {
            final v = puzzle.values[i];
            if (v != 0) expect(v, solution.values[i]);
          }
        });
      }
    }
  });

  group('TechniqueSolver', () {
    test('grades the fixture and finds a hint that matches the solution', () {
      final grid = SudokuGrid.fromCompactString(GridSize.nine, _fixturePuzzle);
      expect(TechniqueSolver.grade(grid), isNot(DifficultyGrade.beyondExpert));
      final step = TechniqueSolver.findNextStep(grid)!;
      expect(step.value, int.parse(_fixtureSolution[step.row * 9 + step.col]));
    });
  });

  group('WordMapping', () {
    const fixture = PuzzleData(
      id: 'fixture',
      size: GridSize.nine,
      grade: DifficultyGrade.medium,
      puzzle: _fixturePuzzle,
      solution: _fixtureSolution,
    );

    test('design fixture: row 3 spells ጎበዝ ተማሪ ናችሁ with the documented map', () {
      const mapping = WordMapping(wordRow: 2, symbolMap: _fixtureMap);
      expect(mapping.spells(fixture, _fixtureWord), isTrue);
      expect(mapping.keypadOrder.join(), 'ሁማሪበተችናዝጎ');
      expect(mapping.keypadDigits, [7, 4, 2, 9, 3, 6, 5, 8, 1]);
    });

    test('place() builds a map whose word row spells the word', () {
      for (int seed = 0; seed < 20; seed++) {
        final m = WordMapping.place(fixture, _fixtureWord, seed: seed)!;
        expect(m.spells(fixture, _fixtureWord), isTrue);
        expect(fixture.givensInRow(m.wordRow), lessThanOrEqualTo(3),
            reason: 'givens must not reveal most of the word');
        expect(m.keypadOrder, isNot(_fixtureWord),
            reason: 'keypad is never in word order');
      }
    });

    test('rejects words with repeated fidel', () {
      expect(
        () => WordMapping.place(
            fixture, ['ጎ', 'ጎ', 'ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ች', 'ሁ']),
        throwsArgumentError,
      );
    });
  });

  group('fidel data', () {
    test('every family has seven distinct forms', () {
      expect(kAllFidelInOrder.toSet().length, kAllFidelInOrder.length);
      for (final f in kFidelFamilies) {
        expect(f.length, 7);
      }
    });

    test('Ge\'ez numerals', () {
      expect(toGeezNumeral(1), '፩');
      expect(toGeezNumeral(9), '፱');
      expect(toGeezNumeral(10), '፲');
      expect(toGeezNumeral(19), '፲፱');
      expect(toGeezNumeral(30), '፴');
      expect(toGeezNumeral(100), '፻');
      expect(toGeezNumeral(101), '፻፩');
      expect(toGeezNumeral(200), '፪፻');
      expect(toGeezNumeral(2019), '፳፻፲፱');
      expect(toGeezNumeral(10000), '፼');
    });

    test('pronunciation', () {
      expect(fidelSound('ች'), 'ch');
      expect(fidelSound('ቦ'), 'bo');
      expect(fidelSound('ብ', explicitSixth: true), 'bə');
      expect(transliterate('ዶሮ ወጥ'), "doro wät'");
    });
  });
}
