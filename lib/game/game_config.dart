import 'package:sudoku_core/sudoku_core.dart';

import '../core/constants/word_bank.dart';

/// What the player sees in the cells.
enum SymbolSet { fidel, geez, arabic }

/// Where a puzzle came from (affects stats, daily calendar and packs).
enum PuzzleSource { quick, daily, pack, classic, onboarding }

/// Everything needed to (re)create a puzzle.
class GameConfig {
  const GameConfig({
    required this.size,
    required this.grade,
    required this.puzzleId,
    required this.symbols,
    required this.source,
    this.wordId,
    this.wordRow,
    this.dailyKey,
    this.seed = 0,
  });

  final GridSize size;
  final DifficultyGrade grade;
  final String puzzleId;
  final SymbolSet symbols;
  final PuzzleSource source;

  /// Word placed in the puzzle (fidel mode only).
  final String? wordId;

  /// Fixed word row, if any (design fixture).
  final int? wordRow;

  /// "2026-10-16" for daily puzzles.
  final String? dailyKey;
  final int seed;

  bool get isWord => symbols == SymbolSet.fidel && wordId != null;
  WordEntry? get word => wordId == null ? null : WordBank.byId(wordId!);

  String get gradeLabel => switch (grade) {
        DifficultyGrade.easy => 'Easy',
        DifficultyGrade.medium => 'Medium',
        DifficultyGrade.hard => 'Hard',
        _ => 'Expert',
      };

  String get sizeLabel => '${size.n} × ${size.n}';

  /// Statistics bucket: '4', '6', '9' or 'classic'.
  String get statsBucket =>
      symbols == SymbolSet.fidel ? '${size.n}' : 'classic';

  /// Same puzzle with a different word / seed (tests and tools).
  GameConfig withWord(String id, int newSeed) => GameConfig(
        size: size,
        grade: grade,
        puzzleId: puzzleId,
        symbols: symbols,
        source: source,
        wordId: id,
        dailyKey: dailyKey,
        seed: newSeed,
      );

  GameConfig withPuzzleId(String id) => GameConfig(
        size: size,
        grade: grade,
        puzzleId: id,
        symbols: symbols,
        source: source,
        wordId: wordId,
        wordRow: wordRow,
        dailyKey: dailyKey,
        seed: seed,
      );

  Map<String, dynamic> toJson() => {
        'size': size.name,
        'grade': grade.name,
        'puzzleId': puzzleId,
        'symbols': symbols.name,
        'source': source.name,
        'wordId': wordId,
        'wordRow': wordRow,
        'dailyKey': dailyKey,
        'seed': seed,
      };

  factory GameConfig.fromJson(Map<String, dynamic> j) => GameConfig(
        size: GridSize.values.byName(j['size'] as String),
        grade: DifficultyGrade.values.byName(j['grade'] as String),
        puzzleId: j['puzzleId'] as String,
        symbols: SymbolSet.values.byName(j['symbols'] as String),
        source: PuzzleSource.values.byName(j['source'] as String),
        wordId: j['wordId'] as String?,
        wordRow: j['wordRow'] as int?,
        dailyKey: j['dailyKey'] as String?,
        seed: (j['seed'] as int?) ?? 0,
      );
}

String gradeLabel(DifficultyGrade g) => switch (g) {
      DifficultyGrade.easy => 'Easy',
      DifficultyGrade.medium => 'Medium',
      DifficultyGrade.hard => 'Hard',
      _ => 'Expert',
    };
