import 'package:sudoku_core/sudoku_core.dart';

import 'game_config.dart';
import 'game_session.dart';

extension SessionSymbols on GameSession {
  /// Visible glyph for an internal digit.
  String glyph(int digit) {
    if (digit == 0) return '';
    final m = mapping;
    if (m != null) return m.symbolMap[digit];
    return switch (symbols) {
      SymbolSet.geez => kGeezNumerals[digit - 1],
      _ => kArabicDigits[digit - 1],
    };
  }

  /// Keypad digits, left to right. Word mode uses ሀለሐ order (never word
  /// order); numerals use 1..N.
  List<int> get keypadDigits =>
      mapping?.keypadDigits ?? [for (int d = 1; d <= n; d++) d];

  /// Slot (0..n-1) where a candidate is drawn inside a cell — follows the
  /// keypad position, not the digit or the word.
  int noteSlot(int digit) => keypadDigits.indexOf(digit);

  String get unitWord => symbols == SymbolSet.fidel ? 'fidel' : 'numeral';
}

const sizeWords = {4: 'Four', 6: 'Six', 9: 'Nine'};

String boxLabel(GridSize s) => '${s.boxRows} × ${s.boxCols}';
