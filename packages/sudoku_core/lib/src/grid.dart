// Core grid model for Ge'ez Sudoku.
// The engine operates on integers 1..N (0 = empty).
// Symbol mapping (int → fidel) is handled at a higher layer.

/// Supported grid sizes.
enum GridSize {
  four(4, 2, 2),
  six(6, 2, 3),
  nine(9, 3, 3);

  const GridSize(this.n, this.boxRows, this.boxCols);

  /// Total symbols / number of cells per row/col.
  final int n;

  /// Number of rows in one box.
  final int boxRows;

  /// Number of columns in one box.
  final int boxCols;
}

/// A single cell position.
class CellPos {
  const CellPos(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is CellPos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 100 + col;

  @override
  String toString() => '($row, $col)';
}

/// Immutable grid model. Holds N×N integers.
class SudokuGrid {
  SudokuGrid(this.size) : _cells = List.filled(size.n * size.n, 0);

  SudokuGrid.from(SudokuGrid other)
      : size = other.size,
        _cells = List<int>.from(other._cells);

  SudokuGrid.fromValues(this.size, List<int> values)
      : _cells = List<int>.from(values) {
    assert(values.length == size.n * size.n);
  }

  final GridSize size;
  final List<int> _cells;

  int get n => size.n;

  int get(int row, int col) => _cells[row * n + col];
  void set(int row, int col, int value) => _cells[row * n + col] = value;

  bool isEmpty(int row, int col) => get(row, col) == 0;

  /// Returns a flat copy of all cell values.
  List<int> get values => List<int>.from(_cells);

  /// Returns a 81-char (or N²-char) string representation.
  /// 0 → '.', 1–9 → '1'–'9'.
  String toCompactString() {
    return _cells.map((v) => v == 0 ? '.' : v.toString()).join();
  }

  static SudokuGrid fromCompactString(GridSize size, String s) {
    final values = s.split('').map((c) => c == '.' ? 0 : int.parse(c)).toList();
    return SudokuGrid.fromValues(size, values);
  }

  /// Returns the box index (0-based) for a given cell.
  int boxIndex(int row, int col) {
    final br = size.boxRows;
    final bc = size.boxCols;
    return (row ~/ br) * (n ~/ bc) + (col ~/ bc);
  }

  /// Returns all cell positions in the same box as (row, col).
  List<CellPos> boxPeers(int row, int col) {
    final br = size.boxRows;
    final bc = size.boxCols;
    final startRow = (row ~/ br) * br;
    final startCol = (col ~/ bc) * bc;
    final result = <CellPos>[];
    for (int r = startRow; r < startRow + br; r++) {
      for (int c = startCol; c < startCol + bc; c++) {
        result.add(CellPos(r, c));
      }
    }
    return result;
  }

  /// Returns all peers (same row, col, box) of a cell, excluding itself.
  Set<CellPos> peers(int row, int col) {
    final result = <CellPos>{};
    for (int c = 0; c < n; c++) {
      if (c != col) result.add(CellPos(row, c));
    }
    for (int r = 0; r < n; r++) {
      if (r != row) result.add(CellPos(r, col));
    }
    for (final p in boxPeers(row, col)) {
      if (p.row != row || p.col != col) result.add(p);
    }
    return result;
  }

  /// Validates the grid — returns true if no rule is violated (ignores empty cells).
  bool isValid() {
    for (int row = 0; row < n; row++) {
      final seen = <int>{};
      for (int col = 0; col < n; col++) {
        final v = get(row, col);
        if (v != 0) {
          if (!seen.add(v)) return false;
        }
      }
    }
    for (int col = 0; col < n; col++) {
      final seen = <int>{};
      for (int row = 0; row < n; row++) {
        final v = get(row, col);
        if (v != 0) {
          if (!seen.add(v)) return false;
        }
      }
    }
    final br = size.boxRows;
    final bc = size.boxCols;
    for (int br0 = 0; br0 < n; br0 += br) {
      for (int bc0 = 0; bc0 < n; bc0 += bc) {
        final seen = <int>{};
        for (int r = br0; r < br0 + br; r++) {
          for (int c = bc0; c < bc0 + bc; c++) {
            final v = get(r, c);
            if (v != 0) {
              if (!seen.add(v)) return false;
            }
          }
        }
      }
    }
    return true;
  }

  bool isFull() => !_cells.contains(0);

  @override
  String toString() {
    final sb = StringBuffer();
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        sb.write(get(r, c));
        if (c < n - 1) sb.write(' ');
      }
      sb.writeln();
    }
    return sb.toString();
  }
}
