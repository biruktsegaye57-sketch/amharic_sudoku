import 'dart:math';
import 'grid.dart';
import 'technique_solver.dart';
import 'transformations.dart';
import 'fidel_data.dart';

/// A numeric puzzle with its unique solution. Internal digits 1..N are the
/// source of truth; what the player sees is decided by a symbol map.
class PuzzleData {
  const PuzzleData({
    required this.id,
    required this.size,
    required this.grade,
    required this.puzzle,
    required this.solution,
  });

  final String id;
  final GridSize size;
  final DifficultyGrade grade;

  /// Compact puzzle string (dots for empty cells).
  final String puzzle;

  /// Compact solution string (all cells filled).
  final String solution;

  int get n => size.n;

  SudokuGrid get puzzleGrid => SudokuGrid.fromCompactString(size, puzzle);
  SudokuGrid get solutionGrid => SudokuGrid.fromCompactString(size, solution);

  int get givenCount => puzzle.split('').where((c) => c != '.').length;

  int givensInRow(int row) {
    int count = 0;
    for (int c = 0; c < n; c++) {
      if (puzzle[row * n + c] != '.') count++;
    }
    return count;
  }

  /// An equivalent puzzle (same grade) made by grid transformations; used
  /// when the bank runs low. Id becomes `<id>~t<seed>`.
  PuzzleData transformed(int seed) {
    final p = SudokuTransformations.randomTransform(puzzleGrid,
        rng: Random(seed), allowRelabel: true);
    final s = SudokuTransformations.randomTransform(solutionGrid,
        rng: Random(seed), allowRelabel: true);
    return PuzzleData(
      id: '$baseId~t$seed',
      size: size,
      grade: grade,
      puzzle: p.toCompactString(),
      solution: s.toCompactString(),
    );
  }

  String get baseId => id.split('~').first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'size': size.name,
        'grade': grade.name,
        'p': puzzle,
        's': solution,
      };

  factory PuzzleData.fromJson(Map<String, dynamic> json) => PuzzleData(
        id: json['id'] as String,
        size: GridSize.values.byName(json['size'] as String),
        grade: DifficultyGrade.values.byName(json['grade'] as String),
        puzzle: json['p'] as String,
        solution: json['s'] as String,
      );
}

/// Places a word in one solved row of a numeric puzzle.
///
/// The word row in the solution holds N distinct digits; mapping the digit at
/// column c to the c-th fidel of the word makes that row spell the word.
class WordMapping {
  const WordMapping({required this.wordRow, required this.symbolMap});

  /// Which row (0-indexed) contains the hidden word.
  final int wordRow;

  /// symbolMap[digit] = fidel. Index 0 unused.
  final List<String> symbolMap;

  /// Maximum givens allowed in the word row (so the word is not handed over).
  static int maxWordRowGivens(GridSize size) => size.n ~/ 3;

  /// Rows that may carry the word.
  static List<int> eligibleRows(PuzzleData data) => [
        for (int r = 0; r < data.n; r++)
          if (data.givensInRow(r) <= maxWordRowGivens(data.size)) r,
      ];

  /// Builds a mapping for [fidel] (word order, length N, all distinct).
  ///
  /// Uses [row] when given and eligible, otherwise tries eligible rows in an
  /// order picked by [seed]. A row is rejected if, after mapping, any other
  /// row, column or main diagonal reads the word or one of [otherWords]
  /// (so the answer is never ambiguous). Returns null if no row works.
  static WordMapping? place(PuzzleData data, List<String> fidel,
      {int seed = 0, int? row, Iterable<List<String>> otherWords = const []}) {
    final n = data.n;
    if (fidel.length != n || fidel.toSet().length != n) {
      throw ArgumentError('Word must have $n distinct fidel, got $fidel');
    }
    final rows = eligibleRows(data)..shuffle(Random(seed));
    if (row != null && rows.remove(row)) rows.insert(0, row);
    final forbidden = {fidel.join(), for (final w in otherWords) w.join()};
    for (final wordRow in rows) {
      final symbolMap = List<String>.filled(n + 1, '');
      for (int c = 0; c < n; c++) {
        final digit = int.parse(data.solution[wordRow * n + c]);
        symbolMap[digit] = fidel[c];
      }
      final m = WordMapping(wordRow: wordRow, symbolMap: symbolMap);
      if (!m._accidentalSpelling(data, forbidden)) return m;
    }
    return null;
  }

  /// Lines (other than the word row) that read a forbidden word.
  bool _accidentalSpelling(PuzzleData data, Set<String> forbidden) {
    final n = data.n;
    String at(int r, int c) => symbolMap[int.parse(data.solution[r * n + c])];
    final lines = <String>[
      for (int r = 0; r < n; r++)
        if (r != wordRow) [for (int c = 0; c < n; c++) at(r, c)].join(),
      for (int c = 0; c < n; c++) [for (int r = 0; r < n; r++) at(r, c)].join(),
      [for (int i = 0; i < n; i++) at(i, i)].join(),
      [for (int i = 0; i < n; i++) at(i, n - 1 - i)].join(),
    ];
    return lines.any(forbidden.contains);
  }

  /// Fidel in ሀለሐ order — the keypad order. Never word order.
  List<String> get keypadOrder => sortFidelInOrder(symbolMap.sublist(1));

  /// Digits in keypad order.
  List<int> get keypadDigits =>
      [for (final f in keypadOrder) symbolMap.indexOf(f)];

  Map<String, dynamic> toJson() => {'row': wordRow, 'map': symbolMap};

  factory WordMapping.fromJson(Map<String, dynamic> json) => WordMapping(
        wordRow: json['row'] as int,
        symbolMap: (json['map'] as List).cast<String>(),
      );

  /// True if the word row of [data]'s solution spells [fidel].
  bool spells(PuzzleData data, List<String> fidel) {
    final n = data.n;
    for (int c = 0; c < n; c++) {
      final digit = int.parse(data.solution[wordRow * n + c]);
      if (symbolMap[digit] != fidel[c]) return false;
    }
    return true;
  }
}
