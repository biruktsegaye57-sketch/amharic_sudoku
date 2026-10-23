import 'grid.dart';

/// Difficulty grades based on required solving techniques.
enum DifficultyGrade {
  easy,
  medium,
  hard,
  expert,
  beyondExpert, // requires guessing — discard these puzzles
}

/// The region a solving step reasons about.
enum HintUnit { cell, row, column, box }

/// A solving step found by the technique solver.
class SolveStep {
  const SolveStep({
    required this.row,
    required this.col,
    required this.value,
    required this.technique,
    this.description = '',
    this.unit = HintUnit.cell,
    this.supportingTechniques = const [],
  });
  final int row;
  final int col;
  final int value;
  final String technique;
  final String description;

  /// Region that forces the value (cell = naked single).
  final HintUnit unit;

  /// Elimination techniques applied before this step became visible.
  final List<String> supportingTechniques;

  SolveStep withSupport(List<String> support) => SolveStep(
        row: row,
        col: col,
        value: value,
        technique: technique,
        description: description,
        unit: unit,
        supportingTechniques: support,
      );
}

/// Human-style technique solver and difficulty grader.
///
/// Attempts techniques in order from easiest to hardest.
/// Records the hardest technique needed.
class TechniqueSolver {
  TechniqueSolver(this.grid);

  final SudokuGrid grid;
  int n = 0;
  late List<Set<int>> _candidates; // candidates per cell (1-indexed values)
  DifficultyGrade _hardestTechnique = DifficultyGrade.easy;

  void _initCandidates() {
    n = grid.n;
    _candidates = List.generate(n * n, (_) => <int>{});
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (grid.isEmpty(r, c)) {
          _candidates[r * n + c] = _computeCandidates(r, c);
        }
      }
    }
  }

  Set<int> _computeCandidates(int row, int col) {
    final all = Set<int>.from(List.generate(n, (i) => i + 1));
    for (int c = 0; c < n; c++) {
      all.remove(grid.get(row, c));
    }
    for (int r = 0; r < n; r++) {
      all.remove(grid.get(r, col));
    }
    for (final p in grid.boxPeers(row, col)) {
      all.remove(grid.get(p.row, p.col));
    }
    return all;
  }

  Set<int> _cands(int r, int c) => _candidates[r * n + c];

  void _place(int row, int col, int value) {
    grid.set(row, col, value);
    _cands(row, col).clear();
    // Remove from row peers
    for (int c = 0; c < n; c++) {
      if (c != col) _cands(row, c).remove(value);
    }
    // Remove from col peers
    for (int r = 0; r < n; r++) {
      if (r != row) _cands(r, col).remove(value);
    }
    // Remove from box peers
    for (final p in grid.boxPeers(row, col)) {
      if (p.row != row || p.col != col) _cands(p.row, p.col).remove(value);
    }
  }

  void _updateGrade(DifficultyGrade g) {
    if (g.index > _hardestTechnique.index) _hardestTechnique = g;
  }

  // ───────── Naked Singles ─────────
  SolveStep? _nakedSingle() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (grid.isEmpty(r, c) && _cands(r, c).length == 1) {
          final v = _cands(r, c).first;
          return SolveStep(
            row: r, col: c, value: v, technique: 'Naked Single',
            description: 'Only candidate for cell ($r,$c) is $v',
          );
        }
      }
    }
    return null;
  }

  // ───────── Hidden Singles ─────────
  SolveStep? _hiddenSingle({bool boxFirst = false}) {
    final checks = boxFirst
        ? [_hiddenSingleInBoxes, _hiddenSingleInRows, _hiddenSingleInCols]
        : [_hiddenSingleInRows, _hiddenSingleInCols, _hiddenSingleInBoxes];
    for (final check in checks) {
      final step = check();
      if (step != null) return step;
    }
    return null;
  }

  SolveStep? _hiddenSingleInRows() {
    for (int r = 0; r < n; r++) {
      for (int v = 1; v <= n; v++) {
        final places = <int>[];
        for (int c = 0; c < n; c++) {
          if (grid.isEmpty(r, c) && _cands(r, c).contains(v)) places.add(c);
        }
        if (places.length == 1) {
          return SolveStep(
            row: r, col: places[0], value: v, technique: 'Hidden Single',
            description: 'Only place for $v in row $r', unit: HintUnit.row,
          );
        }
      }
    }
    return null;
  }

  SolveStep? _hiddenSingleInCols() {
    for (int c = 0; c < n; c++) {
      for (int v = 1; v <= n; v++) {
        final places = <int>[];
        for (int r = 0; r < n; r++) {
          if (grid.isEmpty(r, c) && _cands(r, c).contains(v)) places.add(r);
        }
        if (places.length == 1) {
          return SolveStep(
            row: places[0], col: c, value: v, technique: 'Hidden Single',
            description: 'Only place for $v in column $c',
            unit: HintUnit.column,
          );
        }
      }
    }
    return null;
  }

  SolveStep? _hiddenSingleInBoxes() {
    final br = grid.size.boxRows;
    final bc = grid.size.boxCols;
    for (int br0 = 0; br0 < n; br0 += br) {
      for (int bc0 = 0; bc0 < n; bc0 += bc) {
        for (int v = 1; v <= n; v++) {
          final places = <CellPos>[];
          for (int r = br0; r < br0 + br; r++) {
            for (int c = bc0; c < bc0 + bc; c++) {
              if (grid.isEmpty(r, c) && _cands(r, c).contains(v)) {
                places.add(CellPos(r, c));
              }
            }
          }
          if (places.length == 1) {
            return SolveStep(
              row: places[0].row, col: places[0].col, value: v,
              technique: 'Hidden Single',
              description: 'Only place for $v in box', unit: HintUnit.box,
            );
          }
        }
      }
    }
    return null;
  }

  // ───────── Locked Candidates (Pointing) ─────────
  // If all candidates for a value in a box lie in one row/col,
  // remove that value from the rest of the row/col.
  bool _lockedCandidates() {
    bool changed = false;
    final br = grid.size.boxRows;
    final bc = grid.size.boxCols;
    for (int br0 = 0; br0 < n; br0 += br) {
      for (int bc0 = 0; bc0 < n; bc0 += bc) {
        for (int v = 1; v <= n; v++) {
          final cells = <CellPos>[];
          for (int r = br0; r < br0 + br; r++) {
            for (int c = bc0; c < bc0 + bc; c++) {
              if (grid.isEmpty(r, c) && _cands(r, c).contains(v)) {
                cells.add(CellPos(r, c));
              }
            }
          }
          if (cells.isEmpty) continue;
          // Pointing row
          if (cells.every((p) => p.row == cells[0].row)) {
            final row = cells[0].row;
            for (int c = 0; c < n; c++) {
              if (c < bc0 || c >= bc0 + bc) {
                if (grid.isEmpty(row, c) && _cands(row, c).remove(v)) {
                  changed = true;
                }
              }
            }
          }
          // Pointing col
          if (cells.every((p) => p.col == cells[0].col)) {
            final col = cells[0].col;
            for (int r = 0; r < n; r++) {
              if (r < br0 || r >= br0 + br) {
                if (grid.isEmpty(r, col) && _cands(r, col).remove(v)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }
    return changed;
  }

  // ───────── Naked Pairs/Triples ─────────
  bool _nakedSubset(int size) {
    bool changed = false;
    // Check rows
    for (int r = 0; r < n; r++) {
      final emptyCols = [for (int c = 0; c < n; c++) if (grid.isEmpty(r, c)) c];
      changed |= _applyNakedSubset(
        emptyCols.map((c) => CellPos(r, c)).toList(), size,
        removeFromRow: r, removeFromCol: null,
      );
    }
    // Check cols
    for (int c = 0; c < n; c++) {
      final emptyRows = [for (int r = 0; r < n; r++) if (grid.isEmpty(r, c)) r];
      changed |= _applyNakedSubset(
        emptyRows.map((r) => CellPos(r, c)).toList(), size,
        removeFromRow: null, removeFromCol: c,
      );
    }
    // Check boxes
    final br = grid.size.boxRows;
    final bc = grid.size.boxCols;
    for (int br0 = 0; br0 < n; br0 += br) {
      for (int bc0 = 0; bc0 < n; bc0 += bc) {
        final cells = <CellPos>[];
        for (int r = br0; r < br0 + br; r++) {
          for (int c = bc0; c < bc0 + bc; c++) {
            if (grid.isEmpty(r, c)) cells.add(CellPos(r, c));
          }
        }
        changed |= _applyNakedSubset(cells, size, removeFromBox: CellPos(br0, bc0));
      }
    }
    return changed;
  }

  bool _applyNakedSubset(
    List<CellPos> cells,
    int subsetSize, {
    int? removeFromRow,
    int? removeFromCol,
    CellPos? removeFromBox,
  }) {
    bool changed = false;
    if (cells.length < subsetSize) return false;
    for (int i = 0; i < cells.length; i++) {
      for (int j = i + 1; j < cells.length; j++) {
        final subset = [cells[i], if (subsetSize > 1) cells[j]];
        List<CellPos>? triple;
        if (subsetSize == 3) {
          for (int k = j + 1; k < cells.length; k++) {
            triple = [...subset, cells[k]];
            changed |= _tryNaked(triple, cells, removeFromRow: removeFromRow,
                removeFromCol: removeFromCol, removeFromBox: removeFromBox);
          }
        } else {
          changed |= _tryNaked(subset, cells, removeFromRow: removeFromRow,
              removeFromCol: removeFromCol, removeFromBox: removeFromBox);
        }
      }
    }
    return changed;
  }

  bool _tryNaked(
    List<CellPos> subset,
    List<CellPos> allCells, {
    int? removeFromRow,
    int? removeFromCol,
    CellPos? removeFromBox,
  }) {
    final union = <int>{};
    for (final p in subset) {
      union.addAll(_cands(p.row, p.col));
    }
    if (union.length != subset.length) return false;
    bool changed = false;
    for (final p in allCells) {
      if (subset.any((s) => s == p)) continue;
      for (final v in union) {
        if (_cands(p.row, p.col).remove(v)) changed = true;
      }
    }
    return changed;
  }

  // ───────── Hidden Pairs/Triples ─────────
  bool _hiddenSubset(int size) {
    // Simplified: check rows/cols/boxes for values that appear in exactly `size` cells
    bool changed = false;
    final regions = <List<CellPos>>[];
    // Rows
    for (int r = 0; r < n; r++) {
      regions.add([for (int c = 0; c < n; c++) if (grid.isEmpty(r, c)) CellPos(r, c)]);
    }
    // Cols
    for (int c = 0; c < n; c++) {
      regions.add([for (int r = 0; r < n; r++) if (grid.isEmpty(r, c)) CellPos(r, c)]);
    }
    // Boxes
    final br = grid.size.boxRows;
    final bc = grid.size.boxCols;
    for (int br0 = 0; br0 < n; br0 += br) {
      for (int bc0 = 0; bc0 < n; bc0 += bc) {
        final cells = <CellPos>[];
        for (int r = br0; r < br0 + br; r++) {
          for (int c = bc0; c < bc0 + bc; c++) {
            if (grid.isEmpty(r, c)) cells.add(CellPos(r, c));
          }
        }
        regions.add(cells);
      }
    }
    for (final region in regions) {
      if (region.length < size) continue;
      // Find values that appear in exactly `size` cells in this region
      final valCells = <int, List<CellPos>>{};
      for (int v = 1; v <= n; v++) {
        final places = region.where((p) => _cands(p.row, p.col).contains(v)).toList();
        if (places.length == size) valCells[v] = places;
      }
      // Look for groups of `size` values that share the same `size` cells
      final vals = valCells.keys.toList();
      for (int i = 0; i < vals.length; i++) {
        for (int j = i + 1; j < vals.length; j++) {
          if (size == 2) {
            final cells1 = valCells[vals[i]]!;
            final cells2 = valCells[vals[j]]!;
            final union = {...cells1, ...cells2};
            if (union.length == 2) {
              // Hidden pair: remove all other candidates from these 2 cells
              for (final p in union) {
                final keep = {vals[i], vals[j]};
                if (_cands(p.row, p.col).length > 2) {
                  _cands(p.row, p.col).removeWhere((v) => !keep.contains(v));
                  changed = true;
                }
              }
            }
          }
        }
      }
    }
    return changed;
  }

  // ───────── X-Wing ─────────
  bool _xWing() {
    bool changed = false;
    // Row-based X-Wing
    for (int v = 1; v <= n; v++) {
      final rowPairs = <int, List<int>>{};
      for (int r = 0; r < n; r++) {
        final cols = [for (int c = 0; c < n; c++) if (grid.isEmpty(r, c) && _cands(r, c).contains(v)) c];
        if (cols.length == 2) rowPairs[r] = cols;
      }
      final rows = rowPairs.keys.toList();
      for (int i = 0; i < rows.length; i++) {
        for (int j = i + 1; j < rows.length; j++) {
          if (rowPairs[rows[i]]!.toString() == rowPairs[rows[j]]!.toString()) {
            final col1 = rowPairs[rows[i]]![0];
            final col2 = rowPairs[rows[i]]![1];
            for (int r = 0; r < n; r++) {
              if (r == rows[i] || r == rows[j]) continue;
              if (_cands(r, col1).remove(v)) changed = true;
              if (_cands(r, col2).remove(v)) changed = true;
            }
          }
        }
      }
    }
    return changed;
  }

  // ───────── Main solve loop ─────────

  /// Solves the grid using human-style techniques.
  /// Returns the difficulty grade and a list of steps taken.
  (DifficultyGrade, List<SolveStep>) solve() {
    _initCandidates();
    final steps = <SolveStep>[];
    bool progress = true;
    while (progress && !grid.isFull()) {
      progress = false;
      // Naked singles
      SolveStep? step = _nakedSingle();
      if (step != null) {
        _place(step.row, step.col, step.value);
        steps.add(step);
        progress = true;
        continue;
      }
      // Hidden singles
      step = _hiddenSingle();
      if (step != null) {
        _place(step.row, step.col, step.value);
        steps.add(step);
        _updateGrade(DifficultyGrade.easy);
        progress = true;
        continue;
      }
      // Locked candidates
      if (_lockedCandidates()) {
        _updateGrade(DifficultyGrade.medium);
        progress = true;
        continue;
      }
      // Naked pairs
      if (_nakedSubset(2)) {
        _updateGrade(DifficultyGrade.hard);
        progress = true;
        continue;
      }
      // Hidden pairs
      if (_hiddenSubset(2)) {
        _updateGrade(DifficultyGrade.hard);
        progress = true;
        continue;
      }
      // Naked triples
      if (_nakedSubset(3)) {
        _updateGrade(DifficultyGrade.hard);
        progress = true;
        continue;
      }
      // X-Wing
      if (_xWing()) {
        _updateGrade(DifficultyGrade.expert);
        progress = true;
        continue;
      }
    }
    if (!grid.isFull()) {
      _hardestTechnique = DifficultyGrade.beyondExpert;
    }
    return (_hardestTechnique, steps);
  }

  /// Grade a puzzle without modifying it.
  static DifficultyGrade grade(SudokuGrid puzzle) {
    final copy = SudokuGrid.from(puzzle);
    final ts = TechniqueSolver(copy);
    final (grade, _) = ts.solve();
    return grade;
  }

  /// Find the next placement a person could logically make.
  ///
  /// Prefers singles; if none are visible, applies elimination techniques
  /// until one appears and reports them in [SolveStep.supportingTechniques].
  /// Returns null if the position needs guessing or is already full.
  static SolveStep? findNextStep(SudokuGrid puzzle) {
    final copy = SudokuGrid.from(puzzle);
    final ts = TechniqueSolver(copy);
    ts._initCandidates();
    final support = <String>[];
    for (int guard = 0; guard < 200; guard++) {
      final step = ts._hiddenSingle(boxFirst: true) ?? ts._nakedSingle();
      if (step != null) return step.withSupport(support);
      if (ts._lockedCandidates()) {
        support.add('Locked Candidates');
      } else if (ts._nakedSubset(2)) {
        support.add('Naked Pair');
      } else if (ts._hiddenSubset(2)) {
        support.add('Hidden Pair');
      } else if (ts._nakedSubset(3)) {
        support.add('Naked Triple');
      } else if (ts._xWing()) {
        support.add('X-Wing');
      } else {
        return null;
      }
    }
    return null;
  }
}
