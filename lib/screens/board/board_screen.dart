import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/utils/ethiopic_calendar.dart';
import '../../data/progress.dart';
import '../../data/puzzle_bank.dart';
import '../../data/settings.dart';
import '../../game/game_config.dart';
import '../../game/game_controller.dart';
import '../../game/game_session.dart';
import '../../game/symbols.dart';
import '../../services/audio.dart';
import '../../widgets/confetti.dart';
import '../../widgets/gs_widgets.dart';
import 'keypad.dart';
import 'sheets.dart';
import 'sudoku_board.dart';

/// Route argument: start a new puzzle, or resume the saved one.
class PlayArgs {
  const PlayArgs.start(GameConfig this.config) : resume = false;
  const PlayArgs.resume()
      : config = null,
        resume = true;
  final GameConfig? config;
  final bool resume;
}

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.args});
  final PlayArgs args;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen>
    with WidgetsBindingObserver {
  String? _message;
  bool _messageIsError = false;
  String? _pronounce;
  Timer? _pronounceTimer;
  bool _gameOverOpen = false;
  bool _winHandled = false;
  bool _ready = false;

  /// Given cell the player tried to change (shakes briefly).
  int? _shakeIndex;
  int _shakeTick = 0;

  /// Cells of a just-completed row / column / box (gold sweep).
  Set<int> _flash = const {};
  int _flashTick = 0;
  Timer? _flashTimer;

  /// Whole-board shake when the game is lost.
  int _boardShakeTick = 0;
  bool _loseHandled = false;

  void _shakeGiven(int i) {
    ref.read(feedbackProvider).error();
    setState(() {
      _shakeIndex = i;
      _shakeTick++;
    });
  }

  GameController get _ctrl => ref.read(gameProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.args.resume) {
        if (!_ctrl.resumeSaved()) {
          context.go('/');
          return;
        }
      } else {
        _ctrl.start(widget.args.config!);
      }
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pronounceTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background or screen off. Not "inactive": system dialogs (permission
    // prompts, the notification shade) should not pause the puzzle.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _ctrl.pause();
    }
  }

  void _say(String? text, {bool error = false}) =>
      setState(() {
        _message = text;
        _messageIsError = error;
      });

  // ── Actions ──

  void _onCell(GameSession s, int i) {
    ref.read(feedbackProvider).tap();
    final armed = s.armedDigit;
    final letterFirst =
        ref.read(settingsProvider).inputOrder == InputOrder.letterFirst;
    if (armed != null && letterFirst && s.isGiven(i)) {
      _shakeGiven(i);
      return;
    }
    _ctrl.select(i);
    if (armed != null && letterFirst) {
      _afterPlace(s, armed);
    } else {
      _say(null);
    }
  }

  void _onKey(GameSession s, int digit) {
    final settings = ref.read(settingsProvider);
    if (settings.inputOrder == InputOrder.letterFirst) {
      _ctrl.key(digit);
      ref.read(feedbackProvider).tap();
      _say(s.armedDigit == null ? null : 'Choose a cell for ${s.glyph(digit)}.');
      return;
    }
    if (s.selected == null) {
      _say('Choose a cell first, then a ${s.unitWord}.');
      return;
    }
    if (s.isGiven(s.selected!)) {
      _shakeGiven(s.selected!);
      return;
    }
    final r = _ctrl.key(digit);
    _feedback(s, r);
    _afterPlace(s, digit, result: r);
  }

  void _afterPlace(GameSession s, int digit, {PlaceResult? result}) {
    final i = s.selected;
    if (i == null) return;
    final r = result ??
        (s.values[i] == digit
            ? (s.isWrong(i) ? PlaceResult.mistake : PlaceResult.correct)
            : PlaceResult.ignored);
    if (result == null) _feedback(s, r);
    final settings = ref.read(settingsProvider);
    if (r == PlaceResult.mistake) {
      if (settings.mistakeLimit == MistakeLimit.hidden) {
        _say(null);
      } else if (s.conflictUnit != null) {
        _say('${s.glyph(digit)} already appears in this ${s.conflictUnit}.',
            error: true);
      } else {
        _say("That ${s.unitWord} doesn't belong here.", error: true);
      }
    } else if (r == PlaceResult.correct && s.remaining(digit) == 0) {
      _say('All ${(sizeWords[s.n] ?? '${s.n}').toLowerCase()} ${s.glyph(digit)} placed. A little progress.');
    } else {
      _say(null);
    }
    if (s.isFull && !s.isSolved && s.status == GameStatus.playing) {
      _say(settings.mistakeLimit == MistakeLimit.hidden && !s.showErrors
              ? 'Not quite. Something on the board needs another look.'
              : 'Almost! One cell needs fixing',
          error: true);
    }
  }

  void _feedback(GameSession s, PlaceResult r) {
    final fb = ref.read(feedbackProvider);
    switch (r) {
      case PlaceResult.mistake:
        fb.error();
      case PlaceResult.correct:
        if (s.status == GameStatus.won) return; // the win sound takes over
        final i = s.selected;
        final units = i == null ? const <int>{} : s.completedUnitsAt(i);
        if (units.isEmpty) {
          fb.place();
        } else {
          fb.unit();
          _flashTimer?.cancel();
          setState(() {
            _flash = units;
            _flashTick++;
          });
          _flashTimer = Timer(const Duration(milliseconds: 650), () {
            if (mounted) setState(() => _flash = const {});
          });
        }
      case PlaceResult.ignored:
        if (s.notesMode) fb.note();
    }
  }

  void _onLongKey(GameSession s, int digit) {
    if (!ref.read(settingsProvider).pronunciation || s.mapping == null) return;
    final g = s.glyph(digit);
    GameAudio.speak(g);
    _pronounceTimer?.cancel();
    setState(() => _pronounce = '$g = ${fidelSound(g)}');
    _pronounceTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _pronounce = null);
    });
  }

  Future<void> _openHints(GameSession s) async {
    final choice = await showModalBottomSheet<HintChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HintSheet(session: s, coins: ref.read(progressProvider).coins),
    );
    if (!mounted || choice == null) return;
    final fb = ref.read(feedbackProvider);
    switch (choice) {
      case HintChoice.explain:
        final h = _ctrl.explainNext();
        if (h == null) {
          _say('No single logical step is visible right now. Try Fill cell.');
        } else {
          fb.hint();
          _say(null);
        }
      case HintChoice.fill:
        if (_ctrl.fillCell()) {
          fb.hint();
          _say('Filled. Every letter has a place.');
        }
      case HintChoice.wordClue:
        switch (_ctrl.wordClue()) {
          case WordClueResult.theme:
            fb.hint();
            _say('Theme: ${s.config.word!.theme.label}.');
          case WordClueResult.firstLetter:
            fb.hint();
            _say('The word starts with ${s.config.word!.fidel.first}.');
          case WordClueResult.none:
            break;
        }
      case HintChoice.autoNotes:
        if (_ctrl.autoNotes()) {
          fb.hint();
          _say('Notes filled with every candidate.');
        } else {
          _say('No hints left for auto-notes.');
        }
      case HintChoice.buy:
        if (_ctrl.buyHint()) {
          fb.coin();
          _say('One more hint, for ${Coins.hint} coins.');
        }
      case HintChoice.ad:
        await showAdUnavailable(context);
    }
  }

  Future<void> _openGuess(GameSession s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GuessSheet(
        session: s,
        onSubmit: (g) {
          final r = _ctrl.guess(g);
          final fb = ref.read(feedbackProvider);
          r == GuessResult.correct ? fb.word() : fb.error();
          return r;
        },
      ),
    );
    if (!mounted) return;
    if (s.wordFound) {
      _say('Word found. Keep going to finish the puzzle.');
    } else if (s.guessesLeft == 0) {
      _say('No guesses left, solve to reveal');
    }
  }

  Future<void> _confirmRestart() async {
    await showGsDialog(
      context,
      icon: Icons.restart_alt,
      eyebrow: 'Start fresh',
      title: 'Restart this puzzle?',
      body: 'Progress will be lost. Entries, notes and elapsed time will '
          'reset for this puzzle.',
      primary: 'Restart',
      onPrimary: () {
        _ctrl.restart();
        _winHandled = false;
        _say(null);
      },
      secondary: 'Cancel',
    );
  }

  void _newPuzzle(GameSession s) {
    final bank = ref.read(puzzleBankProvider);
    final avoid = ref.read(progressProvider).recentPuzzles;
    final cfg = s.config;
    final GameConfig next;
    switch (cfg.source) {
      case PuzzleSource.classic:
        next = bank.classic(grade: cfg.grade, symbols: cfg.symbols, avoid: avoid);
      case PuzzleSource.daily:
        context.go('/daily');
        return;
      default:
        next = bank.quick(
          size: cfg.size,
          grade: cfg.grade,
          theme: cfg.word?.theme,
          avoid: avoid,
        );
    }
    _winHandled = false;
    _gameOverOpen = false;
    _say(null);
    _ctrl.start(next);
  }

  Future<void> _showGameOver(GameSession s) async {
    if (_gameOverOpen) return;
    _gameOverOpen = true;
    final choice = await showModalBottomSheet<GameOverChoice>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => GameOverSheet(coins: ref.read(progressProvider).coins),
    );
    _gameOverOpen = false;
    if (!mounted) return;
    switch (choice) {
      case GameOverChoice.secondChance:
        await showAdUnavailable(context);
        if (mounted && s.status == GameStatus.lost) _showGameOver(s);
      case GameOverChoice.buyChance:
        if (_ctrl.buySecondChance()) {
          ref.read(feedbackProvider).coin();
          _loseHandled = false;
          _say('Second chance. One more mistake allowed.');
        }
      case GameOverChoice.newPuzzle:
        _loseHandled = false;
        _newPuzzle(s);
      case GameOverChoice.restart:
        _loseHandled = false;
        _ctrl.restart();
        _say(null);
      case null:
        break;
    }
  }

  void _afterWin(GameSession s) {
    if (_winHandled) return;
    _winHandled = true;
    ref.read(feedbackProvider).win();
    final win = _ctrl.lastWin;
    if (win == null) return;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final progress = ref.read(progressProvider);
      if (win.isDaily && win.dayStreak >= 2) {
        showGsDialog(
          context,
          icon: Icons.local_fire_department_outlined,
          iconColor: context.gs.gold,
          iconBg: context.gs.goldSoft,
          eyebrow: '${win.dayStreak} day streak',
          title: 'Streak saved',
          body: 'Another daily puzzle, another small discovery. '
              'Your spark is still going.',
          primary: 'Keep going',
        );
      } else if (win.newWord && win.collectionSize >= 5 && !progress.rateShown) {
        ref.read(progressProvider.notifier).setRateShown();
        showGsDialog(
          context,
          icon: Icons.star_border,
          eyebrow: '${win.collectionSize} words discovered',
          title: 'Enjoying Ge’ez Sudoku?',
          body: "You've discovered your ${win.collectionSize}th word. A rating "
              'helps more curious minds find their next puzzle.',
          primary: 'Rate app',
          onPrimary: () async {
            final ok = await PlatformBridge.openStore();
            if (!ok && mounted) showToast(context, 'Store not available on this device.');
          },
          secondary: 'Not now',
        );
      }
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.gs;

    if (!_ready || s == null) {
      return Scaffold(
        appBar: const GsAppBar(title: Text('')),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    if (s.status == GameStatus.lost && !_gameOverOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_loseHandled) {
          // Shake the board and play the lose cue, then offer choices.
          _loseHandled = true;
          ref.read(feedbackProvider).lose();
          setState(() => _boardShakeTick++);
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted && s.status == GameStatus.lost) _showGameOver(s);
          });
        } else {
          _showGameOver(s);
        }
      });
    }
    if (s.status == GameStatus.won) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _afterWin(s);
      });
    }

    final cfg = s.config;
    final won = s.status == GameStatus.won;
    final title = cfg.source == PuzzleSource.classic
        ? 'Classic · ${won ? 'Complete' : cfg.gradeLabel}'
        : '${cfg.sizeLabel} • ${won ? 'Complete' : cfg.gradeLabel}';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _ctrl.leave(),
      child: Scaffold(
        appBar: GsAppBar(
          title: Text(title),
          onBack: () => context.canPop() ? context.pop() : context.go('/'),
          actions: [
            if (!s.isWordPuzzle && s.status == GameStatus.playing)
              IconButton(
                tooltip: s.symbols == SymbolSet.geez
                    ? 'Show Arabic numerals'
                    : 'Show Ge’ez numerals',
                icon: Text(s.symbols == SymbolSet.geez ? '1' : '፩',
                    style: GsText.fidel(20).copyWith(color: c.primary)),
                onPressed: _ctrl.toggleNumerals,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (s.status) {
            GameStatus.paused => _PausedView(
                session: s,
                onResume: _ctrl.resume,
                onRestart: _confirmRestart,
                onSettings: () => context.push('/settings'),
                onHome: () => context.go('/'),
              ),
            GameStatus.won => _SolvedView(
                session: s,
                summary: _ctrl.lastWin,
                onNext: () => _newPuzzle(s),
                onHome: () => context.go('/'),
              ),
            _ => _playing(context, s, settings),
          },
        ),
      ),
    );
  }

  Widget _playing(BuildContext context, GameSession s, Settings settings) {
    final c = context.gs;
    final cfg = s.config;
    final hint = _ctrl.hint;
    final step = hint?.step;
    final hideMistakes = settings.mistakeLimit == MistakeLimit.hidden;
    final margin = s.n == 4 ? 20.0 : 12.0;

    Set<int>? hintUnit;
    int? hintTarget = hint?.wrongIndex;
    if (hintTarget != null) hintUnit = {hintTarget};
    if (step != null) {
      hintTarget = step.row * s.n + step.col;
      hintUnit = {
        for (int i = 0; i < s.size; i++)
          if (switch (step.unit) {
            HintUnit.row => s.row(i) == step.row,
            HintUnit.column => s.col(i) == step.col,
            HintUnit.box => s.box(i) == s.box(hintTarget),
            HintUnit.cell => i == hintTarget,
          })
            i,
      };
    }

    final wordRowStyle = !s.isWordPuzzle
        ? WordRowStyle.none
        : s.wordFound
            ? WordRowStyle.guessed
            : (cfg.grade == DifficultyGrade.easy && settings.easyWordRow)
                ? WordRowStyle.band
                : WordRowStyle.none;

    // Mistake counter label.
    final mistakesLabel = s.symbols == SymbolSet.fidel ? 'ስህተት' : 'Mistakes';
    final errorsVisible = !hideMistakes || s.showErrors;
    final offerShowErrors =
        hideMistakes && !s.showErrors && s.isFull && !s.isSolved;
    final mistakesText = settings.mistakeLimit == MistakeLimit.three
        ? '$mistakesLabel ${s.mistakes}/${GameSession.maxMistakes + s.extraChances}'
        : '$mistakesLabel ${s.mistakes}';

    return Column(children: [
      // ── Status row ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
        child: Row(children: [
          if (!hideMistakes)
            Text(mistakesText,
                style: GsText.caption.copyWith(
                    fontSize: 11,
                    color: s.mistakes > 0 ? c.error : c.inkSecondary)),
          const Spacer(),
          if (settings.showTimer)
            Text(formatClock(s.elapsed),
                style: GsText.timer.copyWith(color: c.ink)),
          IconButton(
            tooltip: 'Pause',
            icon: const Icon(Icons.pause),
            onPressed: _ctrl.pause,
          ),
        ]),
      ),
      // ── Word status / mode label ──
      _WordStatus(session: s),
      const SizedBox(height: 8),
      // ── Board + helper line: board as large as fits, slack below ──
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          const helperHeight = 44.0;
          final side = (box.maxWidth - 2 * margin)
              .clamp(0.0, (box.maxHeight - helperHeight).clamp(0.0, double.infinity));
          return Column(children: [
            SizedBox.square(
              dimension: side,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('board-shake-$_boardShakeTick'),
                tween: Tween(begin: _boardShakeTick == 0 ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 500),
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(8 * (1 - t) * math.sin(t * math.pi * 6), 0),
                  child: child,
                ),
                child: SudokuBoard(
                session: s,
                onTap: (i) => _onCell(s, i),
                wordRowStyle: wordRowStyle,
                highlightSameFidel: settings.highlightSameFidel,
                highlightDuplicates: settings.highlightDuplicates,
                showErrors: errorsVisible,
                hintUnit: hintUnit,
                hintTarget: hintTarget,
                largeFidel: settings.largeFidel,
                learningDigits: settings.learningHints,
                shakeIndex: _shakeIndex,
                shakeTick: _shakeTick,
                flashCells: _flash,
                flashTick: _flashTick,
              ),
              ),
            ),
            if (offerShowErrors)
              TextButton(
                onPressed: () {
                  _ctrl.showErrors();
                  _say('Wrong cells are marked in red.', error: true);
                },
                child: const Text('Show errors'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                _message ?? _defaultMessage(s, settings, wordRowStyle),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GsText.caption.copyWith(
                    color: _messageIsError ? c.error : c.inkSecondary),
              ),
            ),
          ]);
        }),
      ),
      if (hint != null)
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 0, margin, 12),
          child: _HintCard(
            session: s,
            hint: hint,
            onShow: () {
              if (hint.wrongIndex != null) {
                _ctrl.select(hint.wrongIndex);
                _ctrl.erase();
                _ctrl.dismissHint();
              } else {
                _ctrl.applyHint();
              }
              _say(null);
            },
            onDone: _ctrl.dismissHint,
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ActionRow(
            session: s,
            onUndo: () {
              _ctrl.undo();
              _say(null);
            },
            onErase: () {
              _ctrl.erase();
              _say(null);
            },
            onNotes: () {
              _ctrl.toggleNotes();
              _say(null);
            },
            onNotesLongPress: settings.autoNotes
                ? () => _say(_ctrl.autoNotes()
                    ? 'Notes filled with every candidate.'
                    : 'Auto-notes needs a hint on this difficulty.')
                : null,
            onHint: () => _openHints(s),
            onGuess: s.isWordPuzzle ? () => _openGuess(s) : null,
          ),
        ),
        const SizedBox(height: 8),
        Stack(clipBehavior: Clip.none, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: Keypad(
              session: s,
              onKey: (d) => _onKey(s, d),
              onLongPress: (d) => _onLongKey(s, d),
            ),
          ),
          if (_pronounce != null)
            Positioned(
              top: -44,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.toast,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_pronounce!,
                      style: GsText.fidel(16, weight: FontWeight.w500)
                          .copyWith(color: c.onToast)),
                ),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: s.wordFound
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.guessed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_circle_outline, size: 18, color: c.guessedInk),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          'You found it!  +${GameSession.coinsForEarlyGuess} coins',
                          overflow: TextOverflow.ellipsis,
                          style: GsText.caption.copyWith(
                              color: c.guessedInk, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                )
              : Text(
                  'Take your time. Every '
                  '${cfg.symbols == SymbolSet.fidel ? 'letter' : 'number'} has a place.',
                  style: GsText.caption.copyWith(color: c.inkSecondary),
                ),
        ),
      ],
    ]);
  }

  String _defaultMessage(GameSession s, Settings settings, WordRowStyle style) {
    final sel = s.selected;
    if (s.notesMode) return 'Notes on · Add or remove pencil marks';
    if (s.isWordPuzzle && !s.wordFound && s.guessesLeft == 0) {
      return 'No guesses left, solve to reveal';
    }
    if (sel != null && s.values[sel] != 0 && settings.highlightSameFidel) {
      return 'Every matching ${s.glyph(s.values[sel])} is highlighted.';
    }
    if (sel != null && s.values[sel] == 0) {
      return 'Choose a ${s.unitWord} for the selected cell.';
    }
    if (s.wordFound) return 'Word found. Keep going to finish the puzzle.';
    if (style == WordRowStyle.band) return 'The word is hidden in the gold row.';
    if (s.symbols != SymbolSet.fidel) {
      return 'Each numeral once per row, column and box.';
    }
    if (s.n != 9) {
      return '${sizeWords[s.n]} fidel. One of each in every row, column and '
          '${boxLabel(s.data.size)} box.';
    }
    return 'One fidel per row, column and box.';
  }
}

/// "🔒 School · Hidden word" + dots, or the discovered word.
class _WordStatus extends StatelessWidget {
  const _WordStatus({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final word = s.config.word;
    if (!s.isWordPuzzle || word == null) {
      final script = s.symbols == SymbolSet.geez ? 'Ge’ez numerals' : 'Arabic numerals';
      return Text('${s.config.sizeLabel} · $script',
          style: GsText.caption.copyWith(color: c.inkSecondary));
    }
    final theme = s.themeVisible ? word.theme.label : null;
    if (s.wordFound) {
      return Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_open, size: 14, color: c.guessedInk),
          const SizedBox(width: 4),
          Flexible(
            child: Text('${word.theme.label} · Word discovered',
                overflow: TextOverflow.ellipsis,
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ),
        ]),
        Text(word.word, style: GsText.fidel(16).copyWith(color: c.primary)),
      ]);
    }
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 14, color: c.inkSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            [
              if (theme != null) theme,
              s.wordClue ? 'Starts with ${word.fidel.first}' : 'Hidden word',
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
            style: GsText.caption.copyWith(color: c.inkSecondary),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      WordDots(count: s.n),
    ]);
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.session,
    required this.hint,
    required this.onShow,
    required this.onDone,
  });

  final GameSession session;
  final HintExplanation hint;
  final VoidCallback onShow;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final step = hint.step;
    final String title, headline, detail, action;
    if (step == null) {
      final i = hint.wrongIndex!;
      title = 'Look at the highlighted cell';
      headline = 'This cell conflicts with the solution';
      detail = 'Logic from a board with a wrong ${s.unitWord} can mislead. '
          'Clear row ${s.row(i) + 1}, column ${s.col(i) + 1} and try again.';
      action = 'Clear it';
    } else {
      final g = s.glyph(step.value);
      final unit = switch (step.unit) {
        HintUnit.row => 'row',
        HintUnit.column => 'column',
        HintUnit.box => 'box',
        HintUnit.cell => 'cell',
      };
      title = 'Look at the highlighted $unit';
      headline = step.unit == HintUnit.cell
          ? 'Naked single: only $g fits this cell'
          : 'Hidden single: $g can only go here in this $unit';
      final reason = step.unit == HintUnit.cell
          ? 'Its row, column and box already hold every other ${s.unitWord}.'
          : 'Every other empty cell in this $unit already sees a $g in its row, '
              'column or box.';
      final support = step.supportingTechniques.isEmpty
          ? ''
          : 'After ${step.supportingTechniques.toSet().join(', ')}: ';
      detail = '$support$reason Place $g at row ${step.row + 1}, column ${step.col + 1}.';
      action = 'Show me';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: step == null ? c.error : c.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline,
                color: step == null ? c.error : c.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: GsText.bodyStrong.copyWith(color: c.ink)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(headline,
              style: GsText.fidel(15, weight: FontWeight.w500).copyWith(color: c.ink)),
          const SizedBox(height: 6),
          Text(detail, style: GsText.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: PrimaryButton(label: action, onPressed: onShow)),
            const SizedBox(width: 8),
            Expanded(child: TonalButton(label: 'Got it', onPressed: onDone)),
          ]),
        ],
      ),
    );
  }
}

class _PausedView extends StatelessWidget {
  const _PausedView({
    required this.session,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onHome,
  });

  final GameSession session;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: c.tonal,
          child: Icon(Icons.pause, size: 32, color: c.primary),
        ),
        const SizedBox(height: 16),
        Text('Paused', style: GsText.title.copyWith(color: c.ink, fontSize: 26)),
        const SizedBox(height: 8),
        Text(formatClock(session.elapsed),
            style: GsText.timer.copyWith(color: c.inkSecondary, fontSize: 20)),
        const SizedBox(height: 16),
        Text("Your puzzle is tucked away.\nTake a breath. We'll keep your place.",
            textAlign: TextAlign.center,
            style: GsText.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: 48),
        SizedBox(width: double.infinity, child: PrimaryButton(label: 'Resume', onPressed: onResume)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: TonalButton(label: 'Restart', onPressed: onRestart)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: TonalButton(label: 'Settings', onPressed: onSettings)),
        const SizedBox(height: 8),
        TextButton(onPressed: onHome, child: const Text('Home')),
      ]),
    );
  }
}

class _SolvedView extends StatelessWidget {
  const _SolvedView({
    required this.session,
    required this.summary,
    required this.onNext,
    required this.onHome,
  });

  final GameSession session;
  final WinSummary? summary;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    final word = s.config.word;
    final isWord = s.isWordPuzzle && word != null;
    final banner = !isWord
        ? 'Puzzle solved.'
        : (summary?.firstWordEver ?? false)
            ? 'Your first little discovery'
            : 'Puzzle solved. Word discovered.';

    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: GsText.bodyStrong.copyWith(
                    color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(label, style: GsText.micro.copyWith(color: c.inkSecondary)),
          ]),
        );

    final shareText = isWord
        ? 'I solved a ${s.config.sizeLabel} Ge’ez Sudoku in ${formatClock(s.elapsed)} '
            'and discovered “${word.word}” — ${word.meaning}.'
        : 'I solved a ${s.config.sizeLabel} Ge’ez Sudoku in ${formatClock(s.elapsed)}.';

    return Stack(children: [
      SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: s.n == 4 ? 20 : 12, vertical: 8),
      child: Column(children: [
        Row(children: [
          Icon(Icons.check, size: 16, color: c.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(banner,
                style: GsText.caption.copyWith(
                    color: c.primary, fontWeight: FontWeight.w600)),
          ),
          Text(s.config.gradeLabel,
              style: GsText.caption.copyWith(color: c.inkSecondary)),
        ]),
        const SizedBox(height: 8),
        SudokuBoard(
          session: s,
          onTap: (_) {},
          interactive: false,
          wordRowStyle: isWord ? WordRowStyle.solved : WordRowStyle.none,
        ),
        const SizedBox(height: 12),
        if (isWord) ...[
          RevealCard(
            word: word,
            compact: true,
            animate: true,
            footer: summary?.newWord == false
                ? '${word.theme.label} · ${word.theme.amharic} · Already in your collection'
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          stat(formatClock(s.elapsed), 'Time'),
          stat('${s.mistakes}', 'Mistakes'),
          stat('${s.hintsUsed}', 'Hints'),
        ]),
        if ((summary?.coinsEarned ?? 0) > 0) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.monetization_on, size: 18, color: c.gold),
            const SizedBox(width: 4),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: summary!.coinsEarned),
              duration: const Duration(milliseconds: 900),
              builder: (context, v, _) => Text('+$v coins',
                  style: GsText.bodyStrong.copyWith(color: c.gold)),
            ),
          ]),
        ],
        if (summary?.personalBest ?? false) ...[
          const SizedBox(height: 8),
          Text('New personal best',
              style: GsText.caption.copyWith(
                  color: c.gold, fontWeight: FontWeight.w600)),
        ],
        if (s.wordFound) ...[
          const SizedBox(height: 8),
          Text('Guessed early · +${GameSession.coinsForEarlyGuess} coins',
              style: GsText.caption.copyWith(color: c.guessedInk)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: s.config.source == PuzzleSource.daily ? 'Back to daily' : 'Next puzzle',
            onPressed: onNext,
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(
            onPressed: () => PlatformBridge.share(shareText),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
          ),
          const SizedBox(width: 16),
          TextButton(onPressed: onHome, child: const Text('Home')),
        ]),
      ]),
      ),
      const Positioned.fill(child: ConfettiBurst()),
    ]);
  }
}
