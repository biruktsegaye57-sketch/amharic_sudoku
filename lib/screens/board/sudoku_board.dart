import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../game/game_config.dart';
import '../../game/game_session.dart';
import '../../game/symbols.dart';

/// How the word row is painted.
enum WordRowStyle { none, band, guessed, solved }

/// The N×N board. Cell state priority (design "Board language"):
/// conflict outline → selected → same fidel → peer → word band → base.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.session,
    required this.onTap,
    this.wordRowStyle = WordRowStyle.none,
    this.highlightSameFidel = true,
    this.highlightDuplicates = true,
    this.showErrors = true,
    this.hintUnit,
    this.hintTarget,
    this.largeFidel = false,
    this.interactive = true,
    this.learningDigits = false,
    this.shakeIndex,
    this.shakeTick = 0,
    this.flashCells = const {},
    this.flashTick = 0,
  });

  /// Cells of a just-completed row / column / box: a short gold sweep.
  final Set<int> flashCells;
  final int flashTick;

  /// Ge'ez numerals: show the Arabic digit small in the corner.
  final bool learningDigits;

  /// Given cell to shake (an attempt to change it); [shakeTick] restarts it.
  final int? shakeIndex;
  final int shakeTick;

  final GameSession session;
  final ValueChanged<int> onTap;
  final WordRowStyle wordRowStyle;
  final bool highlightSameFidel;
  final bool highlightDuplicates;
  final bool showErrors;

  /// Cells to tint for a hint explanation.
  final Set<int>? hintUnit;
  final int? hintTarget;
  final bool largeFidel;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final n = s.n;
    final sel = interactive ? s.selected : null;
    final selValue = sel == null ? 0 : s.values[sel];
    final armed = s.armedDigit;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxWidth / n;
        // 9 × 9 fidel never below 22 px (requirements), when the cell allows.
        final raw = (cell * (n == 9 ? 0.62 : n == 6 ? 0.54 : 0.5)) *
            (largeFidel ? 1.12 : 1);
        final fontSize = n == 9 ? raw.clamp(22.0, cell * 0.8) : raw;
        final noteSize = (cell / (n == 9 ? 3.4 : n == 6 ? 3.6 : 3.2))
            .clamp(8.0, 14.0);

        Widget cellAt(int i) {
          final r = s.row(i);
          final v = s.values[i];
          final given = s.isGiven(i);
          final wrong = showErrors && s.isWrong(i);
          final inWordRow = s.wordRow == r;

          Color bg = c.cell;
          Color ink = given || !interactive ? c.given : c.entry;
          Border? border;

          if (inWordRow) {
            switch (wordRowStyle) {
              case WordRowStyle.band:
              case WordRowStyle.solved:
                bg = c.wordBand;
                if (c.brightness == Brightness.light || wordRowStyle == WordRowStyle.solved) {
                  ink = given || !interactive ? const Color(0xFF1D2433) : c.entry;
                }
              case WordRowStyle.guessed:
                bg = c.guessed;
              case WordRowStyle.none:
                break;
            }
          }
          if (hintUnit != null && hintUnit!.contains(i)) bg = c.wordBand;
          if (sel != null && hintUnit == null && s.arePeers(sel, i)) bg = c.peer;
          final matchDigit = selValue != 0 ? selValue : (armed ?? 0);
          if (highlightSameFidel && matchDigit != 0 && v == matchDigit && i != sel) {
            bg = c.sameFidel;
          }
          if (s.revealed.contains(i)) {
            bg = c.goldSoft;
            border = Border.all(color: c.gold, width: 1.5);
            ink = const Color(0xFF1D2433);
          }
          if (i == sel) bg = c.selected;
          if (flashCells.contains(i)) bg = c.glow.withValues(alpha: 0.55);
          if (hintTarget == i) bg = c.glow;
          if (wrong) {
            bg = c.errorBg;
            ink = c.error;
          }
          if (highlightDuplicates && showErrors && s.conflictIndex == i) {
            border = Border.all(color: c.error, width: 1.5);
          }
          if (wrong && i == sel) {
            border = Border.all(color: c.error, width: 1.5);
          }

          Widget? content;
          if (v != 0) {
            final text = Text(
              s.glyph(v),
              style: GsText.fidel(fontSize,
                      weight: given ? FontWeight.w700 : FontWeight.w500)
                  .copyWith(color: ink, height: 1),
            );
            content = learningDigits && s.symbols == SymbolSet.geez
                ? Stack(children: [
                    Center(child: text),
                    Positioned(
                      right: 2,
                      top: 1,
                      child: Text('$v',
                          style: GsText.micro.copyWith(
                              fontSize: 8, color: c.inkSecondary, height: 1)),
                    ),
                  ])
                : Center(child: text);
          } else if (s.notes[i] != 0) {
            content = _Notes(session: s, index: i, fontSize: noteSize);
          }

          final cellWidget = GestureDetector(
            key: ValueKey('cell-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: interactive ? () => onTap(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(color: bg, border: border),
              child: content == null
                  ? null
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      transitionBuilder: (child, a) => ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.0).animate(a),
                        child: FadeTransition(opacity: a, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey('$v-${s.notes[i]}'),
                        child: content,
                      ),
                    ),
            ),
          );
          if (i != shakeIndex) return cellWidget;
          return TweenAnimationBuilder<double>(
            key: ValueKey('shake-$shakeTick'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 250),
            builder: (context, t, child) => Transform.translate(
              offset: Offset(3 * (1 - t) * math.sin(t * math.pi * 8), 0),
              child: child,
            ),
            child: cellWidget,
          );
        }

        return Semantics(
          label: '$n by $n board',
          child: Stack(children: [
            Column(children: [
              for (int r = 0; r < n; r++)
                Expanded(
                  child: Row(children: [
                    for (int col = 0; col < n; col++)
                      Expanded(child: cellAt(r * n + col)),
                  ]),
                ),
            ]),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridLines(s.data.size, c.boardThin, c.boardThick),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.session, required this.index, required this.fontSize});
  final GameSession session;
  final int index;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final size = s.data.size;
    // 9×9: 3×3 slots; 6×6: 2 rows × 3 columns; 4×4: 2×2.
    final cols = size == GridSize.nine ? 3 : size.boxCols;
    final rows = (s.n / cols).ceil();
    final slots = List<String>.filled(rows * cols, '');
    for (int d = 1; d <= s.n; d++) {
      if (s.hasNote(index, d)) slots[s.noteSlot(d)] = s.glyph(d);
    }
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(children: [
        for (int r = 0; r < rows; r++)
          Expanded(
            child: Row(children: [
              for (int col = 0; col < cols; col++)
                Expanded(
                  child: Center(
                    child: Text(slots[r * cols + col],
                        style: GsText.fidel(fontSize, weight: FontWeight.w500)
                            .copyWith(color: c.inkSecondary, height: 1)),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _GridLines extends CustomPainter {
  _GridLines(this.size, this.thin, this.thick);
  final GridSize size;
  final Color thin;
  final Color thick;

  @override
  void paint(Canvas canvas, Size s) {
    final n = size.n;
    final cell = s.width / n;
    final pThin = Paint()
      ..color = thin
      ..strokeWidth = 0.5;
    final pThick = Paint()
      ..color = thick
      ..strokeWidth = 1.5;
    // Thin rules first so box rules stay on top.
    for (final heavy in [false, true]) {
      for (int i = 1; i < n; i++) {
        final hBox = i % size.boxRows == 0;
        final vBox = i % size.boxCols == 0;
        if (hBox == heavy) {
          canvas.drawLine(Offset(0, i * cell), Offset(s.width, i * cell),
              heavy ? pThick : pThin);
        }
        if (vBox == heavy) {
          canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, s.height),
              heavy ? pThick : pThin);
        }
      }
    }
    canvas.drawRect(
      (Offset.zero & s).deflate(0.75),
      Paint()
        ..color = thick
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_GridLines old) =>
      old.size != size || old.thin != thin || old.thick != thick;
}
