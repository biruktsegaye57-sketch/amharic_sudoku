import 'dart:math';
import 'grid.dart';
import 'solver.dart';
import 'technique_solver.dart';

/// Configuration for puzzle generation.
class GeneratorConfig {
  const GeneratorConfig({
    required this.size,
    required this.targetGrade,
    this.symmetricClues = true,
    this.maxAttempts = 100,
    this.seed,
  });

  final GridSize size;
  final DifficultyGrade targetGrade;
  final bool symmetricClues;
  final int maxAttempts;
  final int? seed;
}

/// Minimum number of givens to keep, per size and difficulty.
/// Clue removal stops at this floor (or earlier, when uniqueness would break).
const Map<GridSize, Map<DifficultyGrade, int>> kClueFloors = {
  GridSize.four: {
    DifficultyGrade.easy: 8,
    DifficultyGrade.medium: 6,
    DifficultyGrade.hard: 5,
    DifficultyGrade.expert: 4,
  },
  GridSize.six: {
    DifficultyGrade.easy: 18,
    DifficultyGrade.medium: 14,
    DifficultyGrade.hard: 12,
    DifficultyGrade.expert: 10,
  },
  GridSize.nine: {
    DifficultyGrade.easy: 36,
    DifficultyGrade.medium: 30,
    DifficultyGrade.hard: 26,
    DifficultyGrade.expert: 22,
  },
};

/// The main puzzle generator.
class PuzzleGenerator {
  PuzzleGenerator(this.config) : _rng = Random(config.seed);

  final GeneratorConfig config;
  final Random _rng;

  /// Generate a numeric puzzle.
  /// Returns the puzzle (partial) and its unique solution (full).
  /// Throws [StateError] if maxAttempts is reached.
  (SudokuGrid puzzle, SudokuGrid solution) generate() {
    for (int attempt = 0; attempt < config.maxAttempts; attempt++) {
      final result = tryGenerate();
      if (result != null) return result;
    }
    throw StateError(
      'Could not generate a ${config.size.name} ${config.targetGrade.name} '
      'puzzle in ${config.maxAttempts} attempts.',
    );
  }

  /// One generation attempt. Returns null if the result does not match the
  /// target grade.
  (SudokuGrid, SudokuGrid)? tryGenerate() {
    final size = config.size;
    final n = size.n;
    final solution = SudokuSolver.generateFullGrid(size, rng: _rng);

    final puzzle = SudokuGrid.from(solution);
    final positions = List.generate(n * n, (i) => CellPos(i ~/ n, i % n))
      ..shuffle(_rng);

    final floor = kClueFloors[size]![config.targetGrade]!;
    int clues = n * n;

    for (final pos in positions) {
      if (clues <= floor) break;
      final val = puzzle.get(pos.row, pos.col);
      if (val == 0) continue;

      CellPos? mirror;
      if (config.symmetricClues) {
        final m = CellPos(n - 1 - pos.row, n - 1 - pos.col);
        if (m != pos && puzzle.get(m.row, m.col) != 0) mirror = m;
      }
      // Never drop below the floor by removing a pair.
      if (mirror != null && clues - 2 < floor) mirror = null;

      puzzle.set(pos.row, pos.col, 0);
      final mirrorVal = mirror == null ? 0 : puzzle.get(mirror.row, mirror.col);
      if (mirror != null) puzzle.set(mirror.row, mirror.col, 0);

      if (SudokuSolver.isUnique(puzzle)) {
        clues -= mirror == null ? 1 : 2;
      } else {
        puzzle.set(pos.row, pos.col, val);
        if (mirror != null) puzzle.set(mirror.row, mirror.col, mirrorVal);
      }
    }

    final grade = TechniqueSolver.grade(puzzle);
    if (grade == DifficultyGrade.beyondExpert) return null;

    if (size == GridSize.nine) {
      // 9×9: the hardest technique required defines the grade.
      if (grade != config.targetGrade) return null;
    } else {
      // Small boards are almost always solvable with singles, so the number of
      // givens defines the grade. Require that removal actually reached the
      // floor (± 1) so difficulties stay distinct.
      if (clues > floor + 1) return null;
    }
    return (puzzle, solution);
  }
}
