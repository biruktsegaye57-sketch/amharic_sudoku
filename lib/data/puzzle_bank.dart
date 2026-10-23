import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../core/constants/word_bank.dart';
import '../core/utils/ethiopic_calendar.dart';
import '../game/game_config.dart';
import '../game/game_session.dart';

/// Pre-generated puzzles bundled in assets/puzzles/bank.json
/// (packages/sudoku_core/tool/generate_bank.dart).
class PuzzleBank {
  PuzzleBank(this._bySize);

  final Map<GridSize, Map<DifficultyGrade, List<PuzzleData>>> _bySize;

  static Future<PuzzleBank> load() async {
    final raw = await rootBundle.loadString('assets/puzzles/bank.json');
    return PuzzleBank.parse(raw);
  }

  factory PuzzleBank.parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final out = <GridSize, Map<DifficultyGrade, List<PuzzleData>>>{};
    for (final size in GridSize.values) {
      final bySize = (json[size.name] as Map?)?.cast<String, dynamic>() ?? {};
      out[size] = {
        for (final e in bySize.entries)
          DifficultyGrade.values.byName(e.key): [
            for (final p in e.value as List)
              PuzzleData.fromJson((p as Map).cast()),
          ],
      };
    }
    return PuzzleBank(out);
  }

  List<PuzzleData> list(GridSize size, DifficultyGrade grade) =>
      _bySize[size]?[grade] ?? const [];

  /// Looks up a puzzle; ids ending in `~t<seed>` are transformed copies.
  PuzzleData? byId(GridSize size, String id) {
    final parts = id.split('~t');
    for (final l in _bySize[size]!.values) {
      for (final p in l) {
        if (p.id == parts.first) {
          return parts.length == 2 ? p.transformed(int.parse(parts[1])) : p;
        }
      }
    }
    return null;
  }

  /// Picks a puzzle, avoiding recently played ones. When every puzzle of the
  /// grade has been played, returns a transformed copy (same difficulty,
  /// different look) instead of repeating one.
  PuzzleData pick(GridSize size, DifficultyGrade grade,
      {required Random rng, List<String> avoid = const []}) {
    final all = list(size, grade);
    final played = {for (final a in avoid) a.split('~').first};
    final fresh = [for (final p in all) if (!played.contains(p.id)) p];
    if (fresh.isNotEmpty) return fresh[rng.nextInt(fresh.length)];
    return all[rng.nextInt(all.length)].transformed(rng.nextInt(1 << 30) + 1);
  }

  // ── Config builders ──

  GameConfig quick({
    required GridSize size,
    required DifficultyGrade grade,
    WordTheme? theme,
    List<String> avoid = const [],
  }) {
    final rng = Random();
    var words = WordBank.forPuzzle(size, grade, theme: theme);
    if (words.isEmpty) words = WordBank.forPuzzle(size, grade);
    final word = words[rng.nextInt(words.length)];
    final puzzle =
        pick(size, word.numericGradeFor(grade)!, rng: rng, avoid: avoid);
    return GameConfig(
      size: size,
      grade: grade,
      puzzleId: puzzle.id,
      symbols: SymbolSet.fidel,
      source: PuzzleSource.quick,
      wordId: word.id,
      seed: rng.nextInt(1 << 30),
    );
  }

  GameConfig classic({
    required DifficultyGrade grade,
    required SymbolSet symbols,
    List<String> avoid = const [],
  }) {
    final rng = Random();
    final puzzle = pick(GridSize.nine, grade, rng: rng, avoid: avoid);
    return GameConfig(
      size: GridSize.nine,
      grade: grade,
      puzzleId: puzzle.id,
      symbols: symbols,
      source: PuzzleSource.classic,
    );
  }

  static int _dayNumber(DateTime day) =>
      dateOnly(day).difference(DateTime(2024, 1, 1)).inDays;

  /// The daily puzzle: 9 × 9 Medium, the same for everyone on a given date.
  GameConfig daily(DateTime day) {
    final n = _dayNumber(day).abs();
    final word = dailyWord(day);
    final puzzles = list(GridSize.nine, word.numericGradeFor(DifficultyGrade.medium)!);
    return GameConfig(
      size: GridSize.nine,
      grade: DifficultyGrade.medium,
      puzzleId: puzzles[(n * 7) % puzzles.length].id,
      symbols: SymbolSet.fidel,
      source: PuzzleSource.daily,
      wordId: word.id,
      dailyKey: dayKey(day),
      seed: n,
    );
  }

  WordEntry dailyWord(DateTime day) {
    final words = WordBank.forPuzzle(GridSize.nine, DifficultyGrade.medium);
    return words[_dayNumber(day).abs() % words.length];
  }

  /// Pack puzzle for a word: grade follows board size.
  GameConfig pack(WordEntry word) {
    final base = switch (word.gridSize) {
      GridSize.four => DifficultyGrade.easy,
      GridSize.six => DifficultyGrade.medium,
      GridSize.nine => DifficultyGrade.medium,
    };
    // Look-alike pairs make the word harder; pair it with an easier grid.
    final numeric = word.numericGradeFor(base) ?? DifficultyGrade.easy;
    final grade = DifficultyGrade.values[
        (numeric.index + word.lookAlikePairs).clamp(0, DifficultyGrade.expert.index)];
    final puzzles = list(word.gridSize, numeric);
    final h = word.id.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFFFF);
    return GameConfig(
      size: word.gridSize,
      grade: grade,
      puzzleId: puzzles[h % puzzles.length].id,
      symbols: SymbolSet.fidel,
      source: PuzzleSource.pack,
      wordId: word.id,
      seed: h,
    );
  }

  /// First puzzle after onboarding: 4 × 4 Easy, ዶሮ ወጥ in row 1.
  GameConfig onboarding4() {
    final puzzle = list(GridSize.four, DifficultyGrade.easy)
        .firstWhere((p) => WordMapping.eligibleRows(p).contains(0));
    return GameConfig(
      size: GridSize.four,
      grade: DifficultyGrade.easy,
      puzzleId: puzzle.id,
      symbols: SymbolSet.fidel,
      source: PuzzleSource.onboarding,
      wordId: 'f4a',
      wordRow: 0,
    );
  }

  /// "I know Sudoku": the design fixture, word row 3 = ጎበዝ ተማሪ ናችሁ.
  GameConfig onboarding9() {
    final fixture = byId(GridSize.nine, 'fixture');
    final puzzle = fixture ?? list(GridSize.nine, DifficultyGrade.medium).first;
    final word = WordBank.byId('s9a');
    return GameConfig(
      size: GridSize.nine,
      // ተ/ቸ in ጎበዝ ተማሪ ናችሁ raises the grade one step.
      grade: DifficultyGrade.values[(puzzle.grade.index + (word?.lookAlikePairs ?? 0))
          .clamp(0, DifficultyGrade.expert.index)],
      puzzleId: puzzle.id,
      symbols: SymbolSet.fidel,
      source: PuzzleSource.onboarding,
      wordId: 's9a',
      wordRow: fixture == null ? null : 2,
    );
  }

  /// Builds a fresh session for [config].
  GameSession session(GameConfig config) {
    final data = byId(config.size, config.puzzleId) ??
        list(config.size, config.grade).first;
    final word = config.word;
    if (!config.isWord || word == null) {
      return GameSession(config: config, data: data, mapping: null);
    }
    final others = [
      for (final w in WordBank.forSize(config.size))
        if (w.id != word.id) w.fidel,
    ];
    var puzzle = data;
    var mapping = WordMapping.place(puzzle, word.fidel,
        seed: config.seed, row: config.wordRow, otherWords: others);
    // Rare: no row avoids an accidental spelling; use a transformed copy.
    for (int t = 1; mapping == null && t < 50; t++) {
      puzzle = data.transformed(config.seed + t);
      mapping = WordMapping.place(puzzle, word.fidel,
          seed: config.seed, otherWords: others);
    }
    return GameSession(
      config: puzzle == data ? config : config.withPuzzleId(puzzle.id),
      data: puzzle,
      mapping: mapping,
    );
  }
}

/// Overridden in main() with the loaded bank.
final puzzleBankProvider = Provider<PuzzleBank>(
  (ref) => throw UnimplementedError('puzzleBankProvider must be overridden'),
);
