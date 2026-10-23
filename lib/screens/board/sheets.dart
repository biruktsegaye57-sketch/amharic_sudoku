import 'package:flutter/material.dart';

import '../../core/constants/features.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../game/game_controller.dart';
import '../../game/game_session.dart';
import '../../game/symbols.dart';
import '../../widgets/gs_widgets.dart';

Widget _handle(BuildContext context) => Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          color: context.gs.inkDisabled,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

// ───────────────────────── Guess the word ─────────────────────────

class GuessSheet extends StatefulWidget {
  const GuessSheet({super.key, required this.session, required this.onSubmit});

  final GameSession session;
  final GuessResult Function(List<String> guess) onSubmit;


  @override
  State<GuessSheet> createState() => _GuessSheetState();
}

enum _GuessState { building, wrong, correct }


class _GuessSheetState extends State<GuessSheet>
    with SingleTickerProviderStateMixin {
  late final List<String?> _slots;
  _GuessState _state = _GuessState.building;
  bool _realWord = false;
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));

  GameSession get s => widget.session;
  List<String> get _word => s.config.word!.fidel;
  bool get _clue => s.wordClue;

  @override
  void initState() {
    super.initState();
    _slots = List<String?>.filled(s.n, null);
    if (_clue) _slots[0] = _word.first;
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  int get _filled => _slots.where((e) => e != null).length;
  int get _firstEditable => _clue ? 1 : 0;

  void _tap(String g) {
    if (_state == _GuessState.correct) return;
    setState(() {
      if (_state == _GuessState.wrong) _clear();
      final i = _slots.indexOf(null);
      if (i >= 0) _slots[i] = g;
    });
  }

  void _clear() {
    for (int i = _firstEditable; i < _slots.length; i++) {
      _slots[i] = null;
    }
    _state = _GuessState.building;
  }

  void _backspace() {
    setState(() {
      if (_state == _GuessState.wrong) {
        _clear();
        return;
      }
      for (int i = _slots.length - 1; i >= _firstEditable; i--) {
        if (_slots[i] != null) {
          _slots[i] = null;
          break;
        }
      }
    });
  }

  void _submit() {
    final r = widget.onSubmit(_slots.cast<String>());
    setState(() {
      _state = r == GuessResult.correct ? _GuessState.correct : _GuessState.wrong;
      _realWord = r == GuessResult.realWord;
    });
    if (r != GuessResult.correct) _shake.forward(from: 0);
    if (r != GuessResult.correct && s.guessesLeft == 0) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final theme = s.themeVisible ? s.config.word!.theme.label : 'Hidden word';
    final left = s.guessesLeft;

    String subtitle;
    String message;
    Color messageColor = c.inkSecondary;
    switch (_state) {
      case _GuessState.correct:
        subtitle = '$theme · Word discovered';
        message = 'You found it! +${GameSession.coinsForEarlyGuess} coins';
        messageColor = c.primary;
      case _GuessState.wrong:
        subtitle = '$theme · $left guess${left == 1 ? '' : 'es'} left';
        message = left == 0
            ? 'No guesses left, solve to reveal'
            : _realWord
                ? "That's a real word, but not this one. $left left"
                : 'Not this one, $left left';
        messageColor = c.error;
      case _GuessState.building:
        subtitle = '$theme · $left guess${left == 1 ? '' : 'es'} left';
        message = _filled == 0 || (_clue && _filled == 1)
            ? 'Tap a fidel to build your word.'
            : _filled == s.n
                ? 'Ready when you are.'
                : '$_filled of ${s.n} letters · Keep going.';
    }

    Widget slot(int i) {
      final g = _slots[i];
      Color bg = c.sunken, border = c.outline, ink = c.ink;
      if (g != null) bg = c.surface;
      if (_state == _GuessState.wrong) {
        bg = c.errorBg;
        border = c.error;
        ink = c.error;
      } else if (_state == _GuessState.correct) {
        bg = c.goldSoft;
        border = c.gold;
        ink = const Color(0xFF1D2433);
      }
      return Expanded(
        child: Container(
          height: s.n == 9 ? 44 : 52,
          margin: EdgeInsets.symmetric(horizontal: s.n == 9 ? 2 : 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(g ?? '·',
              style: GsText.fidel(s.n == 9 ? 18 : 22)
                  .copyWith(color: g == null ? c.inkSecondary : ink)),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            Row(children: [
              Expanded(
                child: Text('Guess the word',
                    style: GsText.title.copyWith(color: c.ink)),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            Text(subtitle, style: GsText.caption.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx = t == 0 || t == 1
                    ? 0.0
                    : 6 * (1 - t) * ((t * 8).floor().isEven ? 1 : -1);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Row(children: [for (int i = 0; i < s.n; i++) slot(i)]),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: GsText.body.copyWith(
                      color: messageColor,
                      fontWeight: _state == _GuessState.building
                          ? FontWeight.w400
                          : FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            ...[
              Row(children: [
                for (final (k, d) in s.keypadDigits.indexed) ...[
                  if (k > 0) SizedBox(width: s.n == 9 ? 3 : 6),
                  Expanded(
                    child: Material(
                      color: c.key,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _state == _GuessState.correct ? null : () => _tap(s.glyph(d)),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(s.glyph(d),
                                style: GsText.fidel(s.n == 9 ? 20 : 24)
                                    .copyWith(color: c.entry)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              if (_state == _GuessState.correct)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(s.config.word!.meaning,
                        style: GsText.body.copyWith(color: c.inkSecondary)),
                  ),
                )
              else
                Row(children: [
                  TextButton(
                    onPressed: () => setState(_clear),
                    child: const Text('Clear all'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove last letter',
                    icon: Icon(Icons.delete_outline, color: c.primary),
                    onPressed: _backspace,
                  ),
                ]),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _state == _GuessState.correct
                  ? PrimaryButton(
                      label: 'Keep solving',
                      onPressed: () => Navigator.of(context).pop())
                  : PrimaryButton(
                      label: 'Submit guess',
                      onPressed: _filled == s.n &&
                              _state == _GuessState.building &&
                              s.guessesLeft > 0
                          ? _submit
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Hints ─────────────────────────

enum HintChoice { explain, fill, wordClue, autoNotes, buy, ad }

class HintSheet extends StatelessWidget {
  const HintSheet({super.key, required this.session, this.coins = 0});
  final GameSession session;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final has = s.hintsLeft > 0;

    Widget option(IconData icon, String title, String sub, HintChoice choice,
        {bool enabled = true}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: c.sunken,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => Navigator.of(context).pop(choice) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Icon(icon, color: enabled ? c.ink : c.inkDisabled),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GsText.bodyStrong.copyWith(
                              color: enabled ? c.ink : c.inkDisabled)),
                      Text(sub,
                          style: GsText.caption.copyWith(color: c.inkSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: enabled ? c.primary : c.inkDisabled),
              ]),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            Row(children: [
              Expanded(
                child: Text('A little help',
                    style: GsText.title.copyWith(color: c.ink)),
              ),
              Text(
                has
                    ? '${s.hintsLeft} hint${s.hintsLeft == 1 ? '' : 's'} left'
                    : 'No hints left',
                style: GsText.caption.copyWith(color: c.primary),
              ),
            ]),
            const SizedBox(height: 8),
            Text("Choose how much you'd like to uncover.",
                style: GsText.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 16),
            option(Icons.lightbulb_outline, 'Explain next step',
                'Learn the logic, keep the discovery.', HintChoice.explain,
                enabled: has),
            option(Icons.edit_outlined, 'Fill cell',
                'Place the correct ${s.unitWord} in one cell.', HintChoice.fill,
                enabled: has),
            if (s.isWordPuzzle)
              s.themeVisible
                  ? option(Icons.document_scanner_outlined, 'Word clue: first letter',
                      'Reveal the first letter of the word.', HintChoice.wordClue,
                      enabled: has && !s.wordClue && !s.wordFound)
                  : option(Icons.document_scanner_outlined, 'Word clue: theme',
                      'Reveal what the hidden word is about.', HintChoice.wordClue,
                      enabled: has && !s.wordFound),
            option(Icons.grid_view, 'Auto-notes',
                s.config.grade.index >= 2
                    ? 'Fill every candidate. Uses 1 hint on Hard and Expert.'
                    : 'Fill every candidate. Free on Easy and Medium.',
                HintChoice.autoNotes,
                enabled: s.config.grade.index < 2 || has),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                icon: Icons.monetization_on_outlined,
                label: 'Buy a hint · ${Coins.hint} coins',
                onPressed: coins >= Coins.hint
                    ? () => Navigator.of(context).pop(HintChoice.buy)
                    : null,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('You have $coins coins · earn more by solving',
                    style: GsText.micro.copyWith(color: c.inkSecondary)),
              ),
            ),
            if (kMonetizationEnabled) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TonalButton(
                  label: '+1 hint · Watch ad',
                  onPressed: () => Navigator.of(context).pop(HintChoice.ad),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: Text('Explain, fill and word clue each use 1 hint.',
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Out of chances ─────────────────────────

enum GameOverChoice { secondChance, buyChance, newPuzzle, restart }

class GameOverSheet extends StatelessWidget {
  const GameOverSheet({super.key, this.coins = 0});
  final int coins;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(context),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.error, width: 1.5),
              ),
              child: Icon(Icons.close, size: 18, color: c.error),
            ),
            const SizedBox(height: 12),
            Text('Out of chances', style: GsText.title.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            Text(
              'Three mistakes, but not the end. Take a second chance or start fresh.',
              textAlign: TextAlign.center,
              style: GsText.body.copyWith(color: c.inkSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                icon: Icons.monetization_on_outlined,
                label: 'Second chance · ${Coins.secondChance} coins',
                onPressed: coins >= Coins.secondChance
                    ? () => Navigator.of(context).pop(GameOverChoice.buyChance)
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text('You have $coins coins',
                  style: GsText.micro.copyWith(color: c.inkSecondary)),
            ),
            if (kMonetizationEnabled) ...[
              SizedBox(
                width: double.infinity,
                child: TonalButton(
                  label: 'Second chance · Watch ad',
                  onPressed: () =>
                      Navigator.of(context).pop(GameOverChoice.secondChance),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TonalButton(
                label: 'New puzzle',
                onPressed: () =>
                    Navigator.of(context).pop(GameOverChoice.newPuzzle),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(GameOverChoice.restart),
              child: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }
}
