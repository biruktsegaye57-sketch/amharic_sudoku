import 'package:sudoku_core/sudoku_core.dart';

import 'game_config.dart';

enum GameStatus { playing, paused, won, lost }

/// Result of placing a value.
enum PlaceResult { ignored, correct, mistake }

/// Result of a word guess.
enum GuessResult { correct, wrong, realWord, noGuessesLeft }

sealed class _Undo {
  const _Undo(this.index);
  final int index;
}

class _CellUndo extends _Undo {
  const _CellUndo(super.index, this.value, this.notes, this.peerNotes);
  final int value;
  final int notes;

  /// Notes removed from peers by auto-remove (index → previous mask).
  final Map<int, int> peerNotes;
}

/// One puzzle in progress. Mutable; the controller notifies listeners.
class GameSession {
  GameSession({
    required this.config,
    required this.data,
    required this.mapping,
    List<int>? values,
    List<int>? notes,
    Set<int>? revealed,
    this.mistakes = 0,
    int? hintsLeft,
    this.hintsUsed = 0,
    this.elapsed = 0,
    this.guessesLeft = 3,
    this.wordFound = false,
    this.wordClue = false,
    this.status = GameStatus.playing,
    this.extraChances = 0,
    this.themeRevealed = false,
    this.symbolOverride,
    List<List<int>>? undoLog,
  })  : n = data.n,
        hintsLeft = hintsLeft ?? defaultHints(config.grade),
        _givens = data.puzzleGrid.values,
        _solution = data.solutionGrid.values,
        values = values ?? data.puzzleGrid.values,
        notes = notes ?? List.filled(data.n * data.n, 0),
        revealed = revealed ?? <int>{} {
    for (final u in undoLog ?? const <List<int>>[]) {
      final peers = <int, int>{};
      for (int k = 3; k + 1 < u.length; k += 2) {
        peers[u[k]] = u[k + 1];
      }
      _undo.add(_CellUndo(u[0], u[1], u[2], peers));
    }
  }

  /// Free hints per puzzle: 3 on Easy and Medium, 1 on Hard, 0 on Expert.
  static int defaultHints(DifficultyGrade g) => switch (g) {
        DifficultyGrade.easy || DifficultyGrade.medium => 3,
        DifficultyGrade.hard => 1,
        _ => 0,
      };

  static const int maxMistakes = 3;
  static const int maxGuesses = 3;
  static const int coinsForEarlyGuess = 50;

  final GameConfig config;
  final PuzzleData data;

  /// Word placement (fidel mode only).
  final WordMapping? mapping;
  final int n;
  final List<int> _givens;
  final List<int> _solution;

  /// Current value of every cell (givens included). 0 = empty.
  final List<int> values;

  /// Candidate bitmask per cell (bit d-1 = digit d).
  final List<int> notes;

  /// Cells filled by a hint.
  final Set<int> revealed;

  int mistakes;
  int hintsLeft;
  int hintsUsed;
  int elapsed;
  int guessesLeft;
  bool wordFound;

  /// The first letter of the word has been revealed with a hint.
  bool wordClue;
  GameStatus status;
  int extraChances;

  /// Hard/Expert hide the theme until a word-clue hint reveals it.
  bool themeRevealed;

  /// Numeral set chosen mid-puzzle (Classic only).
  SymbolSet? symbolOverride;

  /// "Hide mistakes": errors become visible after the player asks.
  bool showErrors = false;

  SymbolSet get symbols => symbolOverride ?? config.symbols;

  /// Theme is shown on Easy and Medium, or once revealed/found.
  bool get themeVisible =>
      config.grade.index <= DifficultyGrade.medium.index ||
      themeRevealed ||
      wordFound;

  // ── Transient UI state ──
  int? selected;
  bool notesMode = false;

  /// Armed keypad digit for "letter first" input.
  int? armedDigit;

  /// Cell that conflicts with the latest wrong entry (shown outlined).
  int? conflictIndex;
  String? conflictUnit;

  final List<_Undo> _undo = [];

  // ── Queries ──
  int get size => n * n;
  bool isGiven(int i) => _givens[i] != 0;
  int solutionAt(int i) => _solution[i];
  bool isWrong(int i) => values[i] != 0 && values[i] != _solution[i];
  bool get canUndo => _undo.isNotEmpty;
  bool get isWordPuzzle => mapping != null;
  int? get wordRow => mapping?.wordRow;
  int row(int i) => i ~/ n;
  int col(int i) => i % n;
  int box(int i) {
    final s = data.size;
    return (row(i) ~/ s.boxRows) * (n ~/ s.boxCols) + col(i) ~/ s.boxCols;
  }

  bool arePeers(int a, int b) =>
      a != b && (row(a) == row(b) || col(a) == col(b) || box(a) == box(b));

  bool get isFull => !values.contains(0);
  bool get isSolved {
    for (int i = 0; i < size; i++) {
      if (values[i] != _solution[i]) return false;
    }
    return true;
  }

  /// Number of cells currently holding [digit] correctly or as a given.
  int placedCount(int digit) {
    int c = 0;
    for (int i = 0; i < size; i++) {
      if (values[i] == digit && !isWrong(i)) c++;
    }
    return c;
  }

  int remaining(int digit) => n - placedCount(digit);

  /// Word-row cells currently filled correctly (for the progress dots).
  int get wordRowProgress {
    final r = wordRow;
    if (r == null) return 0;
    int c = 0;
    for (int col = 0; col < n; col++) {
      final i = r * n + col;
      if (values[i] != 0 && !isWrong(i)) c++;
    }
    return c;
  }

  /// Grid of givens plus correct entries (input for hints).
  SudokuGrid get correctGrid => SudokuGrid.fromValues(
        data.size,
        [for (int i = 0; i < size; i++) isWrong(i) ? 0 : values[i]],
      );

  bool hasNote(int i, int digit) => notes[i] & (1 << (digit - 1)) != 0;

  // ── Mutations ──

  /// Place [digit] in cell [i] (or toggle a note in notes mode).
  PlaceResult input(int i, int digit,
      {required bool autoRemoveNotes,
      required bool countMistakes,
      required bool enforceLimit}) {
    if (status != GameStatus.playing || isGiven(i)) return PlaceResult.ignored;
    if (notesMode) {
      if (values[i] != 0) return PlaceResult.ignored;
      _undo.add(_CellUndo(i, values[i], notes[i], const {}));
      notes[i] ^= 1 << (digit - 1);
      return PlaceResult.ignored;
    }
    if (values[i] == digit) return PlaceResult.ignored;

    final peerNotes = <int, int>{};
    final correct = digit == _solution[i];
    if (correct && autoRemoveNotes) {
      for (int j = 0; j < size; j++) {
        if (arePeers(i, j) && hasNote(j, digit)) {
          peerNotes[j] = notes[j];
          notes[j] &= ~(1 << (digit - 1));
        }
      }
    }
    _undo.add(_CellUndo(i, values[i], notes[i], peerNotes));
    values[i] = digit; // notes stay hidden underneath and return on erase
    revealed.remove(i);

    if (!correct) {
      _findConflict(i, digit);
      if (countMistakes) mistakes++;
      if (enforceLimit && mistakes >= maxMistakes + extraChances) {
        status = GameStatus.lost;
      }
      return PlaceResult.mistake;
    }
    conflictIndex = null;
    conflictUnit = null;
    if (isSolved) status = GameStatus.won;
    return PlaceResult.correct;
  }

  void _findConflict(int i, int digit) {
    conflictIndex = null;
    conflictUnit = null;
    for (int j = 0; j < size; j++) {
      if (j != i && values[j] == digit && arePeers(i, j)) {
        conflictIndex = j;
        conflictUnit = row(i) == row(j)
            ? 'row'
            : col(i) == col(j)
                ? 'column'
                : 'box';
        return;
      }
    }
  }

  void erase(int i) {
    if (status != GameStatus.playing || isGiven(i)) return;
    if (values[i] == 0 && notes[i] == 0) return;
    _undo.add(_CellUndo(i, values[i], notes[i], const {}));
    if (values[i] != 0) {
      values[i] = 0; // hidden notes come back
    } else {
      notes[i] = 0;
    }
    revealed.remove(i);
    if (conflictIndex != null) {
      conflictIndex = null;
      conflictUnit = null;
    }
  }

  void undo() {
    if (status != GameStatus.playing) return;
    // A used hint is not refunded: player moves on hint-filled cells are
    // skipped rather than undoing the hint.
    while (_undo.isNotEmpty && revealed.contains(_undo.last.index)) {
      _undo.removeLast();
    }
    if (_undo.isEmpty) return;
    final u = _undo.removeLast() as _CellUndo;
    values[u.index] = u.value;
    notes[u.index] = u.notes;
    u.peerNotes.forEach((j, mask) => notes[j] = mask);
    conflictIndex = null;
    conflictUnit = null;
    selected = u.index;
  }

  /// Fill [i] with its solution value as a hint.
  void reveal(int i) {
    if (isGiven(i)) return;
    values[i] = _solution[i];
    revealed.add(i);
    conflictIndex = null;
    if (isSolved) status = GameStatus.won;
  }

  bool useHint() {
    if (hintsLeft <= 0) return false;
    hintsLeft--;
    hintsUsed++;
    return true;
  }

  /// Guess the hidden word. [guess] is fidel in word order.
  GuessResult guessWord(List<String> guess, List<String> word,
      {bool Function(List<String>)? isRealWord}) {
    if (guessesLeft <= 0 || wordFound) return GuessResult.noGuessesLeft;
    if (guess.join() == word.join()) {
      wordFound = true;
      return GuessResult.correct;
    }
    guessesLeft--;
    return (isRealWord?.call(guess) ?? false)
        ? GuessResult.realWord
        : GuessResult.wrong;
  }

  /// Candidates for every empty cell from the visible board.
  void fillAutoNotes() {
    for (int i = 0; i < size; i++) {
      if (values[i] != 0) continue;
      int mask = (1 << n) - 1;
      for (int j = 0; j < size; j++) {
        if (values[j] != 0 && arePeers(i, j)) mask &= ~(1 << (values[j] - 1));
      }
      notes[i] = mask;
    }
  }

  /// Cells of every row, column and box through [i] that are now complete
  /// and correct (for the completion flash). Empty if none.
  Set<int> completedUnitsAt(int i) {
    final out = <int>{};
    bool done(Iterable<int> cells) =>
        cells.every((j) => values[j] != 0 && !isWrong(j));
    final rowCells = [for (int c = 0; c < n; c++) row(i) * n + c];
    final colCells = [for (int r = 0; r < n; r++) r * n + col(i)];
    final boxCells = [for (int j = 0; j < size; j++) if (box(j) == box(i)) j];
    for (final unit in [rowCells, colCells, boxCells]) {
      if (done(unit)) out.addAll(unit);
    }
    return out;
  }

  /// First wrong cell, if any.
  int? get firstWrong {
    for (int i = 0; i < size; i++) {
      if (isWrong(i)) return i;
    }
    return null;
  }

  void restart() {
    for (int i = 0; i < size; i++) {
      values[i] = _givens[i];
      notes[i] = 0;
    }
    revealed.clear();
    _undo.clear();
    mistakes = 0;
    elapsed = 0;
    hintsLeft = defaultHints(config.grade);
    themeRevealed = false;
    showErrors = false;
    hintsUsed = 0;
    guessesLeft = 3;
    wordFound = false;
    wordClue = false;
    extraChances = 0;
    selected = null;
    notesMode = false;
    armedDigit = null;
    conflictIndex = null;
    status = GameStatus.playing;
  }

  // ── Persistence ──
  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'data': data.toJson(),
        'mapping': mapping?.toJson(),
        'values': values.join(','),
        'notes': notes.join(','),
        'revealed': revealed.toList(),
        'mistakes': mistakes,
        'hintsLeft': hintsLeft,
        'hintsUsed': hintsUsed,
        'elapsed': elapsed,
        'guessesLeft': guessesLeft,
        'wordFound': wordFound,
        'wordClue': wordClue,
        'extraChances': extraChances,
        'themeRevealed': themeRevealed,
        'symbolOverride': symbolOverride?.name,
        'undo': [
          for (final u in _undo.cast<_CellUndo>())
            [u.index, u.value, u.notes, for (final e in u.peerNotes.entries) ...[e.key, e.value]],
        ],
      };

  factory GameSession.fromJson(Map<String, dynamic> j) {
    List<int> ints(String s) => [for (final p in s.split(',')) int.parse(p)];
    final m = j['mapping'];
    return GameSession(
      config: GameConfig.fromJson((j['config'] as Map).cast()),
      data: PuzzleData.fromJson((j['data'] as Map).cast()),
      mapping: m == null ? null : WordMapping.fromJson((m as Map).cast()),
      values: ints(j['values'] as String),
      notes: ints(j['notes'] as String),
      revealed: {...(j['revealed'] as List).cast<int>()},
      mistakes: j['mistakes'] as int,
      hintsLeft: j['hintsLeft'] as int,
      hintsUsed: j['hintsUsed'] as int,
      elapsed: j['elapsed'] as int,
      guessesLeft: j['guessesLeft'] as int,
      wordFound: j['wordFound'] as bool,
      wordClue: (j['wordClue'] as bool?) ?? false,
      extraChances: (j['extraChances'] as int?) ?? 0,
      themeRevealed: (j['themeRevealed'] as bool?) ?? false,
      symbolOverride: j['symbolOverride'] == null
          ? null
          : SymbolSet.values.byName(j['symbolOverride'] as String),
      undoLog: [
        for (final u in (j['undo'] as List? ?? const []))
          (u as List).cast<int>(),
      ],
      status: GameStatus.paused,
    );
  }
}
