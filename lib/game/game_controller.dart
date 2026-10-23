import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../core/constants/word_bank.dart';
import '../data/progress.dart';
import '../data/puzzle_bank.dart';
import '../data/settings.dart';
import 'game_config.dart';
import 'game_session.dart';

/// What happened when a game was won, for the solved panel and prompts.
class WinSummary {
  const WinSummary({
    required this.newWord,
    required this.firstWordEver,
    required this.collectionSize,
    required this.dayStreak,
    required this.isDaily,
    this.personalBest = false,
    this.coinsEarned = 0,
  });

  /// Coins for this win (difficulty + daily bonus; early guess paid earlier).
  final int coinsEarned;

  /// Faster than every earlier win in the same size and difficulty.
  final bool personalBest;

  final bool newWord;
  final bool firstWordEver;
  final int collectionSize;
  final int dayStreak;
  final bool isDaily;
}

/// A hint explanation to show under the board: either the next logical
/// step, or (if the board has errors) the first wrong cell.
class HintExplanation {
  const HintExplanation(SolveStep this.step) : wrongIndex = null;
  const HintExplanation.wrong(int this.wrongIndex) : step = null;
  final SolveStep? step;
  final int? wrongIndex;
}

enum WordClueResult { none, theme, firstLetter }

/// The coin economy.
class Coins {
  Coins._();
  static const hint = 40;
  static const secondChance = 100;
  static const dailyBonus = 20;

  static int forWin(DifficultyGrade g) => switch (g) {
        DifficultyGrade.easy => 10,
        DifficultyGrade.medium => 20,
        DifficultyGrade.hard => 35,
        _ => 50,
      };
}

class GameController extends Notifier<GameSession?> {
  Timer? _timer;
  WinSummary? lastWin;
  HintExplanation? hint;

  @override
  GameSession? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  // Always notify: the session is mutated in place.
  @override
  bool updateShouldNotify(GameSession? previous, GameSession? next) => true;

  Settings get _settings => ref.read(settingsProvider);
  PuzzleBank get _bank => ref.read(puzzleBankProvider);
  ProgressController get _progress => ref.read(progressProvider.notifier);

  void _emit() => state = state;

  // ── Lifecycle ──

  void start(GameConfig config) {
    final s = _bank.session(config);
    lastWin = null;
    hint = null;
    _progress.markPlayed(config.puzzleId);
    state = s;
    _startTimer();
    save();
  }

  /// Saved in-progress game, if any (without loading it).
  GameSession? peekSaved() {
    final raw = ref.read(prefsProvider).getString(ProgressController.sessionKey);
    if (raw == null) return null;
    try {
      return GameSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool resumeSaved() {
    final s = peekSaved();
    if (s == null) return false;
    lastWin = null;
    hint = null;
    s.status = GameStatus.playing;
    state = s;
    _startTimer();
    return true;
  }

  void save() {
    final s = state;
    final prefs = ref.read(prefsProvider);
    if (s == null || s.status == GameStatus.won || s.status == GameStatus.lost) {
      prefs.remove(ProgressController.sessionKey);
      return;
    }
    prefs.setString(ProgressController.sessionKey, jsonEncode(s.toJson()));
  }

  void clearSaved() =>
      ref.read(prefsProvider).remove(ProgressController.sessionKey);

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s != null && s.status == GameStatus.playing) {
        s.elapsed++;
        _emit();
        if (s.elapsed % 5 == 0) save();
      }
    });
  }

  void pause() {
    final s = state;
    if (s == null || s.status != GameStatus.playing) return;
    s.status = GameStatus.paused;
    save();
    _emit();
  }

  void resume() {
    final s = state;
    if (s == null || s.status != GameStatus.paused) return;
    s.status = GameStatus.playing;
    _emit();
  }

  void leave() {
    save();
    _timer?.cancel();
  }

  void restart() {
    final s = state;
    if (s == null) return;
    s.restart();
    lastWin = null;
    hint = null;
    _startTimer();
    save();
    _emit();
  }

  // ── Input ──


  void select(int? index) {
    final s = state;
    if (s == null || s.status != GameStatus.playing) return;
    if (_settings.inputOrder == InputOrder.letterFirst &&
        index != null &&
        s.armedDigit != null) {
      s.selected = index;
      _input(s, index, s.armedDigit!);
      return;
    }
    s.selected = index;
    _emit();
  }

  /// Keypad tap. Returns the placement result (for feedback).
  PlaceResult key(int digit) {
    final s = state;
    if (s == null || s.status != GameStatus.playing) return PlaceResult.ignored;
    if (_settings.inputOrder == InputOrder.letterFirst) {
      s.armedDigit = s.armedDigit == digit ? null : digit;
      _emit();
      return PlaceResult.ignored;
    }
    final i = s.selected;
    if (i == null) return PlaceResult.ignored;
    return _input(s, i, digit);
  }

  PlaceResult _input(GameSession s, int i, int digit) {
    hint = null;
    final r = s.input(i, digit,
        autoRemoveNotes: _settings.autoRemoveNotes,
        countMistakes: _settings.mistakeLimit != MistakeLimit.hidden,
        enforceLimit: _settings.mistakeLimit == MistakeLimit.three);
    _after(s);
    return r;
  }

  void erase() {
    final s = state;
    if (s == null || s.selected == null) return;
    s.erase(s.selected!);
    save();
    _emit();
  }

  void undo() {
    final s = state;
    if (s == null) return;
    s.undo();
    save();
    _emit();
  }

  void toggleNotes() {
    final s = state;
    if (s == null) return;
    s.notesMode = !s.notesMode;
    _emit();
  }

  // ── Hints ──

  /// Explain the next logical step. Uses one hint. If the board has a wrong
  /// entry, points that out first, since logic from a wrong board misleads.
  HintExplanation? explainNext() {
    final s = state;
    if (s == null || s.hintsLeft <= 0) return null;
    final wrong = s.firstWrong;
    if (wrong != null) {
      s.useHint();
      hint = HintExplanation.wrong(wrong);
      s.selected = wrong;
      s.showErrors = true;
      save();
      _emit();
      return hint;
    }
    final step = TechniqueSolver.findNextStep(s.correctGrid);
    if (step == null) return null;
    s.useHint();
    hint = HintExplanation(step);
    s.selected = step.row * s.n + step.col;
    save();
    _emit();
    return hint;
  }

  /// "Show me": place the explained value (no extra hint).
  void applyHint() {
    final s = state;
    final step = hint?.step;
    if (s == null || step == null) return;
    s.reveal(step.row * s.n + step.col);
    hint = null;
    _after(s);
  }

  void dismissHint() {
    hint = null;
    _emit();
  }

  /// Fill the selected cell (or the next logical cell). Uses one hint.
  bool fillCell() {
    final s = state;
    if (s == null || s.hintsLeft <= 0) return false;
    int? target = s.selected;
    if (target == null || s.isGiven(target) || (s.values[target] != 0 && !s.isWrong(target))) {
      final step = TechniqueSolver.findNextStep(s.correctGrid);
      if (step != null) {
        target = step.row * s.n + step.col;
      } else {
        target = null;
        for (int i = 0; i < s.size; i++) {
          if (s.values[i] == 0 || s.isWrong(i)) {
            target = i;
            break;
          }
        }
      }
    }
    if (target == null) return false;
    s.useHint();
    s.selected = target;
    s.reveal(target);
    _after(s);
    return true;
  }

  /// Word clue: reveals the theme if it is not shown yet (Hard/Expert),
  /// otherwise the first fidel. Uses one hint; disabled once the word is found.
  WordClueResult wordClue() {
    final s = state;
    if (s == null || !s.isWordPuzzle || s.wordFound || s.hintsLeft <= 0) {
      return WordClueResult.none;
    }
    final WordClueResult r;
    if (!s.themeVisible) {
      s.themeRevealed = true;
      r = WordClueResult.theme;
    } else if (!s.wordClue) {
      s.wordClue = true;
      r = WordClueResult.firstLetter;
    } else {
      return WordClueResult.none;
    }
    s.useHint();
    save();
    _emit();
    return r;
  }

  /// Fill every empty cell's notes with its candidates. Free on Easy and
  /// Medium; costs a hint on Hard and Expert. Returns false if not allowed.
  bool autoNotes() {
    final s = state;
    if (s == null || s.status != GameStatus.playing) return false;
    if (s.config.grade.index >= DifficultyGrade.hard.index && !s.useHint()) {
      return false;
    }
    s.fillAutoNotes();
    save();
    _emit();
    return true;
  }

  /// "Hide mistakes": reveal wrong cells on request.
  void showErrors() {
    final s = state;
    if (s == null) return;
    s.showErrors = true;
    _emit();
  }

  /// Switch Ge'ez ↔ Arabic numerals mid-puzzle (numeric puzzles only).
  void toggleNumerals() {
    final s = state;
    if (s == null || s.isWordPuzzle) return;
    s.symbolOverride =
        s.symbols == SymbolSet.geez ? SymbolSet.arabic : SymbolSet.geez;
    save();
    _emit();
  }

  // ── Word guess ──

  GuessResult guess(List<String> fidel) {
    final s = state;
    final word = s?.config.word;
    if (s == null || word == null) return GuessResult.noGuessesLeft;
    final r = s.guessWord(fidel, word.fidel,
        isRealWord: (g) => WordBank.matching(g) != null);
    if (r == GuessResult.correct) {
      _progress.addCoins(GameSession.coinsForEarlyGuess);
    }
    save();
    _emit();
    return r;
  }

  /// Buy one hint with coins. Returns false if the balance is too low.
  bool buyHint() {
    final s = state;
    if (s == null) return false;
    if (!_progress.spendCoins(Coins.hint)) return false;
    s.hintsLeft++;
    save();
    _emit();
    return true;
  }

  /// Second chance after the third mistake, paid with coins.
  bool buySecondChance() {
    final s = state;
    if (s == null || s.status != GameStatus.lost) return false;
    if (!_progress.spendCoins(Coins.secondChance)) return false;
    grantExtraChance();
    return true;
  }

  /// Second chance: one more mistake allowed, puzzle continues.
  void grantExtraChance() {
    final s = state;
    if (s == null || s.status != GameStatus.lost) return;
    s.extraChances++;
    s.status = GameStatus.playing;
    _startTimer();
    save();
    _emit();
  }

  // ── Completion ──

  void _after(GameSession s) {
    if (s.status == GameStatus.won) {
      _timer?.cancel();
      _onWin(s);
    } else if (s.status == GameStatus.lost) {
      _timer?.cancel();
      _record(s, won: false);
    }
    save();
    _emit();
  }

  void _record(GameSession s, {required bool won}) {
    _progress.addRecord(GameRecord(
      bucket: s.config.statsBucket,
      grade: s.config.grade,
      won: won,
      seconds: s.elapsed,
      mistakes: s.mistakes,
      hints: s.hintsUsed,
      isWord: s.isWordPuzzle,
      guessedEarly: s.wordFound,
      date: DateTime.now(),
    ));
  }

  void _onWin(GameSession s) {
    final before = ref.read(progressProvider);
    int? best;
    for (final r in before.wins) {
      if (r.bucket == s.config.statsBucket && r.grade == s.config.grade) {
        if (best == null || r.seconds < best) best = r.seconds;
      }
    }
    _record(s, won: true);
    bool newWord = false;
    final word = s.config.word;
    if (s.isWordPuzzle && word != null) {
      newWord = _progress.collect(CollectedWord(
        wordId: word.id,
        date: DateTime.now(),
        size: s.config.size,
        grade: s.config.grade,
        seconds: s.elapsed,
        mistakes: s.mistakes,
        hints: s.hintsUsed,
        guessedEarly: s.wordFound,
      ));
    }
    final day = s.config.dailyKey;
    if (day != null && word != null) {
      _progress.markDaily(day, word.id, s.elapsed);
    }
    final earned = Coins.forWin(s.config.grade) + (day != null ? Coins.dailyBonus : 0);
    _progress.addCoins(earned);
    final after = ref.read(progressProvider);
    lastWin = WinSummary(
      newWord: newWord,
      firstWordEver: before.collection.isEmpty && newWord,
      collectionSize: after.collection.length,
      dayStreak: after.dayStreak,
      isDaily: day != null,
      personalBest: best != null && s.elapsed < best,
      coinsEarned: earned,
    );
    clearSaved();
  }
}

final gameProvider =
    NotifierProvider<GameController, GameSession?>(GameController.new);
