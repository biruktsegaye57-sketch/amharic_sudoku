// Generates the bundled puzzle bank.
//
//   cd packages/sudoku_core
//   dart run tool/generate_bank.dart ../../assets/puzzles/bank.json
//
// Every puzzle has a unique solution, matches its grade, and has at least one
// row with few enough givens to carry a hidden word.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

/// Design-handoff fixture (word row 3 = ጎበዝ ተማሪ ናችሁ).
const _fixture = (
  '53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79',
  '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
);

const _perGrade = {GridSize.four: 60, GridSize.six: 150, GridSize.nine: 400};
const _expertBudget = Duration(minutes: 12);

/// Relabels digits by first appearance so relabelled copies compare equal.
String normalise(String p) {
  final map = <String, String>{};
  return p.split('').map((c) => c == '.' ? '.' : map.putIfAbsent(c, () => '${map.length + 1}')).join();
}

void main(List<String> args) {
  final out = args.isEmpty ? 'bank.json' : args.first;
  final bank = <String, Map<String, List<Map<String, dynamic>>>>{};

  for (final size in GridSize.values) {
    final bySize = bank[size.name] = {};
    for (final grade in [
      DifficultyGrade.easy,
      DifficultyGrade.medium,
      DifficultyGrade.hard,
      DifficultyGrade.expert,
    ]) {
      final list = bySize[grade.name] = [];
      final seen = <String>{};
      if (size == GridSize.nine) {
        final g = TechniqueSolver.grade(
            SudokuGrid.fromCompactString(GridSize.nine, _fixture.$1));
        if (g == grade) {
          list.add(PuzzleData(
            id: 'fixture',
            size: size,
            grade: grade,
            puzzle: _fixture.$1,
            solution: _fixture.$2,
          ).toJson());
          seen.add(normalise(_fixture.$1));
        }
      }
      final sw = Stopwatch()..start();
      int seed = size.index * 1000003 + grade.index * 7919;
      int attempts = 0;
      while (list.length < _perGrade[size]!) {
        if (grade == DifficultyGrade.expert &&
            size == GridSize.nine &&
            sw.elapsed > _expertBudget &&
            list.length >= 100) {
          break;
        }
        attempts++;
        if (attempts > 400000) break; // small boards: distinct puzzles run out
        final gen = PuzzleGenerator(GeneratorConfig(
          size: size,
          targetGrade: grade,
          seed: seed++,
          maxAttempts: 1,
        ));
        final result = gen.tryGenerate();
        if (result == null) continue;
        final (puzzle, solution) = result;
        final data = PuzzleData(
          id: '${size.name[0]}${grade.name[0]}${list.length.toString().padLeft(3, '0')}',
          size: size,
          grade: grade,
          puzzle: puzzle.toCompactString(),
          solution: solution.toCompactString(),
        );
        if (WordMapping.eligibleRows(data).isEmpty) continue;
        if (!seen.add(normalise(data.puzzle))) continue;
        list.add(data.toJson());
      }
      stderr.writeln('${size.name} ${grade.name}: ${list.length} puzzles, '
          '$attempts attempts, ${sw.elapsed.inMilliseconds} ms');
    }
  }

  File(out).writeAsStringSync(jsonEncode(bank));
  stderr.writeln('Wrote $out');
}
