import 'dart:math';
import 'grid.dart';

/// Valid grid transformations that preserve Sudoku validity and difficulty.
///
/// These can be used to generate many unique-looking puzzles from one source.
/// NOTE: Do NOT apply relabelling to word puzzles after the symbol map is set.
class SudokuTransformations {
  SudokuTransformations._();

  /// Transpose the grid (swap rows and columns).
  static SudokuGrid transpose(SudokuGrid grid) {
    final result = SudokuGrid(grid.size);
    for (int r = 0; r < grid.n; r++) {
      for (int c = 0; c < grid.n; c++) {
        result.set(c, r, grid.get(r, c));
      }
    }
    return result;
  }

  /// Rotate 90° clockwise.
  static SudokuGrid rotate90(SudokuGrid grid) {
    final result = SudokuGrid(grid.size);
    final n = grid.n;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        result.set(c, n - 1 - r, grid.get(r, c));
      }
    }
    return result;
  }

  /// Swap two rows within the same band (band = group of boxRows rows).
  static SudokuGrid swapRowsInBand(SudokuGrid grid, int band, int row1, int row2) {
    assert(row1 ~/ grid.size.boxRows == band);
    assert(row2 ~/ grid.size.boxRows == band);
    final result = SudokuGrid.from(grid);
    for (int c = 0; c < grid.n; c++) {
      final v1 = grid.get(row1, c);
      final v2 = grid.get(row2, c);
      result.set(row1, c, v2);
      result.set(row2, c, v1);
    }
    return result;
  }

  /// Swap two columns within the same stack.
  static SudokuGrid swapColsInStack(SudokuGrid grid, int stack, int col1, int col2) {
    assert(col1 ~/ grid.size.boxCols == stack);
    assert(col2 ~/ grid.size.boxCols == stack);
    final result = SudokuGrid.from(grid);
    for (int r = 0; r < grid.n; r++) {
      final v1 = grid.get(r, col1);
      final v2 = grid.get(r, col2);
      result.set(r, col1, v2);
      result.set(r, col2, v1);
    }
    return result;
  }

  /// Swap two bands (horizontal strips of boxRows rows).
  static SudokuGrid swapBands(SudokuGrid grid, int band1, int band2) {
    final br = grid.size.boxRows;
    var result = SudokuGrid.from(grid);
    for (int i = 0; i < br; i++) {
      final r1 = band1 * br + i;
      final r2 = band2 * br + i;
      for (int c = 0; c < grid.n; c++) {
        final v1 = result.get(r1, c);
        final v2 = result.get(r2, c);
        result.set(r1, c, v2);
        result.set(r2, c, v1);
      }
    }
    return result;
  }

  /// Relabel symbols (only for numeric/classic puzzles, NOT word puzzles).
  /// [permutation] maps digit (1-indexed) to new digit.
  static SudokuGrid relabel(SudokuGrid grid, List<int> permutation) {
    assert(permutation.length == grid.n);
    final result = SudokuGrid(grid.size);
    final map = [0, ...permutation]; // index 0 = empty
    for (int r = 0; r < grid.n; r++) {
      for (int c = 0; c < grid.n; c++) {
        final v = grid.get(r, c);
        result.set(r, c, v == 0 ? 0 : map[v]);
      }
    }
    return result;
  }

  /// Apply a random set of transformations (safe for both word and numeric puzzles
  /// if relabelling is disabled).
  static SudokuGrid randomTransform(
    SudokuGrid grid, {
    Random? rng,
    bool allowRelabel = false,
  }) {
    final r = rng ?? Random();
    var result = SudokuGrid.from(grid);
    final n = grid.n;
    final br = grid.size.boxRows;
    final bc = grid.size.boxCols;
    final numBands = n ~/ br;
    final numStacks = n ~/ bc;

    // Random row swaps within bands
    for (int band = 0; band < numBands; band++) {
      final r1 = band * br + r.nextInt(br);
      final r2 = band * br + r.nextInt(br);
      if (r1 != r2) result = swapRowsInBand(result, band, r1, r2);
    }

    // Random col swaps within stacks
    for (int stack = 0; stack < numStacks; stack++) {
      final c1 = stack * bc + r.nextInt(bc);
      final c2 = stack * bc + r.nextInt(bc);
      if (c1 != c2) result = swapColsInStack(result, stack, c1, c2);
    }

    // Random band swap
    if (numBands > 1 && r.nextBool()) {
      final b1 = r.nextInt(numBands);
      final b2 = r.nextInt(numBands);
      if (b1 != b2) result = swapBands(result, b1, b2);
    }

    // Transpose (only square boxes stay valid when transposed)
    final flip = r.nextBool();
    if (flip && br == bc) result = transpose(result);

    // Relabel (numeric only)
    if (allowRelabel) {
      final perm = List.generate(n, (i) => i + 1)..shuffle(r);
      result = relabel(result, perm);
    }

    return result;
  }
}
