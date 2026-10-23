import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../core/utils/ethiopic_calendar.dart';
import 'settings.dart';

/// One finished game (won or lost).
class GameRecord {
  const GameRecord({
    required this.bucket,
    required this.grade,
    required this.won,
    required this.seconds,
    required this.mistakes,
    required this.hints,
    required this.isWord,
    required this.guessedEarly,
    required this.date,
  });

  /// '4', '6', '9' or 'classic'.
  final String bucket;
  final DifficultyGrade grade;
  final bool won;
  final int seconds;
  final int mistakes;
  final int hints;
  final bool isWord;
  final bool guessedEarly;
  final DateTime date;

  bool get perfect => won && mistakes == 0 && hints == 0;

  Map<String, dynamic> toJson() => {
        'b': bucket,
        'g': grade.name,
        'w': won,
        's': seconds,
        'm': mistakes,
        'h': hints,
        'iw': isWord,
        'ge': guessedEarly,
        'd': date.millisecondsSinceEpoch,
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        bucket: j['b'] as String,
        grade: DifficultyGrade.values.byName(j['g'] as String),
        won: j['w'] as bool,
        seconds: j['s'] as int,
        mistakes: j['m'] as int,
        hints: j['h'] as int,
        isWord: j['iw'] as bool,
        guessedEarly: j['ge'] as bool,
        date: DateTime.fromMillisecondsSinceEpoch(j['d'] as int),
      );
}

/// A discovered word in the collection.
class CollectedWord {
  const CollectedWord({
    required this.wordId,
    required this.date,
    required this.size,
    required this.grade,
    required this.seconds,
    required this.mistakes,
    required this.hints,
    required this.guessedEarly,
  });

  final String wordId;
  final DateTime date;
  final GridSize size;
  final DifficultyGrade grade;
  final int seconds;
  final int mistakes;
  final int hints;
  final bool guessedEarly;

  Map<String, dynamic> toJson() => {
        'id': wordId,
        'd': date.millisecondsSinceEpoch,
        'sz': size.name,
        'g': grade.name,
        's': seconds,
        'm': mistakes,
        'h': hints,
        'ge': guessedEarly,
      };

  factory CollectedWord.fromJson(Map<String, dynamic> j) => CollectedWord(
        wordId: j['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(j['d'] as int),
        size: GridSize.values.byName(j['sz'] as String),
        grade: DifficultyGrade.values.byName(j['g'] as String),
        seconds: j['s'] as int,
        mistakes: j['m'] as int,
        hints: j['h'] as int,
        guessedEarly: j['ge'] as bool,
      );
}

class DailyResult {
  const DailyResult({required this.wordId, required this.seconds});
  final String wordId;
  final int seconds;
}

class Progress {
  const Progress({
    this.records = const [],
    this.collection = const {},
    this.daily = const {},
    this.coins = 0,
    this.lessons = const {},
    this.recentPuzzles = const [],
    this.rateShown = false,
    this.reports = 0,
  });

  final List<GameRecord> records;

  /// wordId → discovery (first time it was earned).
  final Map<String, CollectedWord> collection;

  /// dayKey → result.
  final Map<String, DailyResult> daily;
  final int coins;

  /// lessonId → 'started' | 'done'.
  final Map<String, String> lessons;

  /// Recently played puzzle ids (avoid immediate repeats).
  final List<String> recentPuzzles;
  final bool rateShown;
  final int reports;

  Progress copyWith({
    List<GameRecord>? records,
    Map<String, CollectedWord>? collection,
    Map<String, DailyResult>? daily,
    int? coins,
    Map<String, String>? lessons,
    List<String>? recentPuzzles,
    bool? rateShown,
    int? reports,
  }) =>
      Progress(
        records: records ?? this.records,
        collection: collection ?? this.collection,
        daily: daily ?? this.daily,
        coins: coins ?? this.coins,
        lessons: lessons ?? this.lessons,
        recentPuzzles: recentPuzzles ?? this.recentPuzzles,
        rateShown: rateShown ?? this.rateShown,
        reports: reports ?? this.reports,
      );

  // ── Derived ──
  List<GameRecord> get wins => [for (final r in records) if (r.won) r];

  /// Consecutive days (ending today or yesterday) with at least one win.
  int get dayStreak => _streak(_winDays, DateTime.now());

  int get bestDayStreak {
    final days = _winDays.toList()..sort();
    int best = 0, cur = 0;
    DateTime? prev;
    for (final d in days) {
      cur = prev != null && d.difference(prev).inDays == 1 ? cur + 1 : 1;
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }

  Set<DateTime> get _winDays => {for (final r in wins) dateOnly(r.date)};

  static int _streak(Set<DateTime> days, DateTime now) {
    var d = dateOnly(now);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    int s = 0;
    while (days.contains(d)) {
      s++;
      d = d.subtract(const Duration(days: 1));
    }
    return s;
  }

  /// Consecutive word wins (most recent first) where the word was guessed early.
  int get guessStreak {
    int s = 0;
    for (final r in wins.reversed) {
      if (!r.isWord) continue;
      if (!r.guessedEarly) break;
      s++;
    }
    return s;
  }

  int get earlyGuessCount => collection.values.where((c) => c.guessedEarly).length;

  /// Longest run of consecutive word wins guessed before solving.
  int get bestGuessStreak {
    int best = 0, cur = 0;
    for (final r in wins) {
      if (!r.isWord) continue;
      cur = r.guessedEarly ? cur + 1 : 0;
      if (cur > best) best = cur;
    }
    return best;
  }

  /// (current, best) consecutive wins in one size/mode and difficulty.
  /// A loss ends the streak.
  (int, int) winStreak(String bucket, DifficultyGrade grade) {
    int cur = 0, best = 0;
    for (final r in records) {
      if (r.bucket != bucket || r.grade != grade) continue;
      cur = r.won ? cur + 1 : 0;
      if (cur > best) best = cur;
    }
    return (cur, best);
  }

  /// Rank title from total puzzles solved.
  Rank get rank => Rank.forSolved(wins.length);


  Map<String, dynamic> toJson() => {
        'records': [for (final r in records) r.toJson()],
        'collection': {
          for (final e in collection.entries) e.key: e.value.toJson(),
        },
        'daily': {
          for (final e in daily.entries)
            e.key: {'w': e.value.wordId, 's': e.value.seconds},
        },
        'coins': coins,
        'lessons': lessons,
        'recent': recentPuzzles,
        'rateShown': rateShown,
        'reports': reports,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        records: [
          for (final r in (j['records'] as List? ?? const []))
            GameRecord.fromJson((r as Map).cast()),
        ],
        collection: {
          for (final e in ((j['collection'] as Map?) ?? const {}).entries)
            e.key as String: CollectedWord.fromJson((e.value as Map).cast()),
        },
        daily: {
          for (final e in ((j['daily'] as Map?) ?? const {}).entries)
            e.key as String: DailyResult(
              wordId: (e.value as Map)['w'] as String,
              seconds: (e.value as Map)['s'] as int,
            ),
        },
        coins: (j['coins'] as int?) ?? 0,
        lessons: ((j['lessons'] as Map?) ?? const {}).cast<String, String>(),
        recentPuzzles: ((j['recent'] as List?) ?? const []).cast<String>(),
        rateShown: (j['rateShown'] as bool?) ?? false,
        reports: (j['reports'] as int?) ?? 0,
      );
}

class ProgressController extends Notifier<Progress> {
  static const _key = 'progress.v1';
  static const sessionKey = 'session.v1';

  @override
  Progress build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const Progress();
    try {
      return Progress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Progress();
    }
  }

  void _set(Progress p) {
    state = p;
    ref.read(prefsProvider).setString(_key, jsonEncode(p.toJson()));
  }

  void addRecord(GameRecord r) => _set(state.copyWith(
        records: [...state.records, r].length > 500
            ? [...state.records.skip(state.records.length - 499), r]
            : [...state.records, r],
      ));

  /// Adds a word to the collection. Returns true if it is new.
  bool collect(CollectedWord w) {
    if (state.collection.containsKey(w.wordId)) return false;
    _set(state.copyWith(collection: {...state.collection, w.wordId: w}));
    return true;
  }

  void markDaily(String day, String wordId, int seconds) => _set(state.copyWith(
        daily: {...state.daily, day: DailyResult(wordId: wordId, seconds: seconds)},
      ));

  void addCoins(int c) => _set(state.copyWith(coins: state.coins + c));

  /// Spends [c] coins if the balance allows. Returns false otherwise.
  bool spendCoins(int c) {
    if (state.coins < c) return false;
    _set(state.copyWith(coins: state.coins - c));
    return true;
  }

  void setLesson(String id, String status) {
    if (state.lessons[id] == 'done' && status != 'done') return;
    _set(state.copyWith(lessons: {...state.lessons, id: status}));
  }

  void markPlayed(String puzzleId) {
    final list = [...state.recentPuzzles.where((p) => p != puzzleId), puzzleId];
    _set(state.copyWith(
      recentPuzzles: list.length > 60 ? list.sublist(list.length - 60) : list,
    ));
  }

  void setRateShown() => _set(state.copyWith(rateShown: true));
  void addReport() => _set(state.copyWith(reports: state.reports + 1));
}

final progressProvider =
    NotifierProvider<ProgressController, Progress>(ProgressController.new);

/// Titles earned by puzzles solved, from beginner to master.
class Rank {
  const Rank(this.title, this.amharic, this.from, this.next);
  final String title;
  final String amharic;
  final int from;

  /// Puzzles needed for the next rank (null at the top).
  final int? next;

  static const _ladder = [
    (0, 'Beginner', 'ጀማሪ'),
    (10, 'Learner', 'ተማሪ'),
    (30, 'Reader', 'አንባቢ'),
    (75, 'Solver', 'ፈቺ'),
    (150, 'Scholar', 'ሊቅ'),
    (300, 'Master', 'መምህር'),
  ];

  static Rank forSolved(int solved) {
    for (int i = _ladder.length - 1; i >= 0; i--) {
      final (from, en, am) = _ladder[i];
      if (solved >= from) {
        return Rank(en, am, from,
            i + 1 < _ladder.length ? _ladder[i + 1].$1 : null);
      }
    }
    return const Rank('Beginner', 'ጀማሪ', 0, 10);
  }
}
