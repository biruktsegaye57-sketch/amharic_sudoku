import 'dart:math';
import 'grid.dart';

/// Bitmask-based backtracking solver.
/// Uses bitmasks for O(1) candidate lookup per row/col/box.
///
/// Performance target: countSolutions() < 50ms on a low-end phone.
class SudokuSolver {
  SudokuSolver(this.grid)
      : n = grid.n,
        _rowMask = List.filled(grid.n, 0),
        _colMask = List.filled(grid.n, 0),
        _boxMask = List.filled(grid.n, 0) {
    _initMasks();
  }

  final SudokuGrid grid;
  final int n;
  final List<int> _rowMask;
  final List<int> _colMask;
  final List<int> _boxMask;

  void _initMasks() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final v = grid.get(r, c);
        if (v != 0) {
          final bit = 1 << (v - 1);
          _rowMask[r] |= bit;
          _colMask[c] |= bit;
          _boxMask[grid.boxIndex(r, c)] |= bit;
        }
      }
    }
  }

  int _candidates(int row, int col) {
    final full = (1 << n) - 1;
    return full &
        ~(_rowMask[row] | _colMask[col] | _boxMask[grid.boxIndex(row, col)]);
  }

  void _place(int row, int col, int value) {
    final bit = 1 << (value - 1);
    grid.set(row, col, value);
    _rowMask[row] |= bit;
    _colMask[col] |= bit;
    _boxMask[grid.boxIndex(row, col)] |= bit;
  }

  void _remove(int row, int col, int value) {
    final bit = 1 << (value - 1);
    grid.set(row, col, 0);
    _rowMask[row] &= ~bit;
    _colMask[col] &= ~bit;
    _boxMask[grid.boxIndex(row, col)] &= ~bit;
  }

  /// Find the empty cell with the fewest candidates (MRV heuristic).
  CellPos? _nextCell() {
    CellPos? best;
    int bestCount = n + 1;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (grid.isEmpty(r, c)) {
          final cands = _candidates(r, c);
          final count = _popcount(cands);
          if (count == 0) return null; // dead end
          if (count < bestCount) {
            bestCount = count;
            best = CellPos(r, c);
            if (bestCount == 1) return best; // can't do better
          }
        }
      }
    }
    return best;
  }

  int _popcount(int x) {
    var v = x;
    v -= (v >> 1) & 0x55555555;
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    v = (v + (v >> 4)) & 0x0f0f0f0f;
    // Dart ints are 64-bit: mask to 32 bits before taking the top byte.
    return ((v * 0x01010101) & 0xFFFFFFFF) >> 24;
  }

  /// Solve the grid in-place. Returns true if a solution was found.
  bool solve() {
    final cell = _nextCell();
    if (cell == null) return grid.isFull(); // no empty cell = solved or dead end
    final cands = _candidates(cell.row, cell.col);
    if (cands == 0) return false;
    var bits = cands;
    while (bits != 0) {
      final bit = bits & (-bits);
      bits &= ~bit;
      final value = _trailingZeros(bit) + 1;
      _place(cell.row, cell.col, value);
      if (solve()) return true;
      _remove(cell.row, cell.col, value);
    }
    return false;
  }

  int _trailingZeros(int x) {
    if (x == 0) return 32;
    int count = 0;
    var v = x;
    if ((v & 0xFFFF) == 0) { count += 16; v >>= 16; }
    if ((v & 0xFF) == 0)   { count += 8;  v >>= 8;  }
    if ((v & 0xF) == 0)    { count += 4;  v >>= 4;  }
    if ((v & 0x3) == 0)    { count += 2;  v >>= 2;  }
    if ((v & 0x1) == 0)    { count += 1;  }
    return count;
  }

  /// Count the number of solutions, stopping at [max].
  /// Returns 0, 1, or max (clamped).
  int countSolutions({int max = 2}) {
    return _count(max);
  }

  int _count(int max) {
    final cell = _nextCell();
    if (cell == null) return grid.isFull() ? 1 : 0;
    final cands = _candidates(cell.row, cell.col);
    if (cands == 0) return 0;
    int total = 0;
    var bits = cands;
    while (bits != 0 && total < max) {
      final bit = bits & (-bits);
      bits &= ~bit;
      final value = _trailingZeros(bit) + 1;
      _place(cell.row, cell.col, value);
      total += _count(max - total);
      _remove(cell.row, cell.col, value);
    }
    return total;
  }

  /// Returns the solution grid if one exists, else null.
  static SudokuGrid? solveGrid(SudokuGrid grid) {
    final copy = SudokuGrid.from(grid);
    final solver = SudokuSolver(copy);
    if (solver.solve()) return copy;
    return null;
  }

  /// Returns the number of solutions (max 2 for uniqueness check).
  static int uniquenessCheck(SudokuGrid grid) {
    final copy = SudokuGrid.from(grid);
    final solver = SudokuSolver(copy);
    return solver.countSolutions(max: 2);
  }

  /// Returns true if the puzzle has exactly one solution.
  static bool isUnique(SudokuGrid grid) => uniquenessCheck(grid) == 1;

  /// Fills a grid with a complete valid solution using randomised backtracking.
  static SudokuGrid generateFullGrid(GridSize size, {Random? rng}) {
    final r = rng ?? Random();
    final grid = SudokuGrid(size);
    final solver = SudokuSolver(grid);
    solver._fillRandom(r);
    return grid;
  }

  bool _fillRandom(Random r) {
    final cell = _nextCell();
    if (cell == null) return grid.isFull();
    final cands = _candidates(cell.row, cell.col);
    if (cands == 0) return false;
    // Shuffle candidates
    final values = <int>[];
    var bits = cands;
    while (bits != 0) {
      final bit = bits & (-bits);
      bits &= ~bit;
      values.add(_trailingZeros(bit) + 1);
    }
    values.shuffle(r);
    for (final v in values) {
      _place(cell.row, cell.col, v);
      if (_fillRandom(r)) return true;
      _remove(cell.row, cell.col, v);
    }
    return false;
  }
}
