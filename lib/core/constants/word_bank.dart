import 'package:sudoku_core/sudoku_core.dart';

/// Puzzle themes (= puzzle packs). Keys match assets/words/words.json.
enum WordTheme {
  food('Food', 'ምግብ', 'A taste of Ethiopia', 'assets/images/packs/food.jpg'),
  cities('Cities', 'ከተሞች', 'Places with long stories',
      'assets/images/packs/cities.jpg'),
  proverbs('Proverbs', 'ተረትና ምሳሌ', 'Old wisdom, short words',
      'assets/images/packs/proverbs.jpg'),
  holidays('Holidays', 'በዓላት', 'Days worth celebrating',
      'assets/images/packs/holidays.jpg'),
  animals('Animals', 'እንስሳት', 'From the highlands to the rift',
      'assets/images/packs/animals.jpg'),
  school('School', 'ትምህርት', 'Letters, lessons and learners',
      'assets/images/packs/school.jpg');

  const WordTheme(this.label, this.amharic, this.tagline, this.image);
  final String label;
  final String amharic;
  final String tagline;
  final String image;
}

/// A playable hidden word.
class WordEntry {
  WordEntry(this.record, this.theme)
      : lookAlikePairs = WordRules.lookAlikePairs(record.word);

  final WordRecord record;
  final WordTheme theme;

  /// Each derived look-alike pair (ሰ/ሸ, ተ/ቸ, ነ/ኘ …) raises the puzzle one
  /// difficulty step.
  final int lookAlikePairs;

  String get id => record.id;
  String get word => record.word;

  /// English meaning.
  String get meaning => record.meaningEn;
  String get meaningAm => record.meaningAm;
  List<String> get fidel => record.fidel;
  int get length => record.length;
  bool get approved => record.approved;

  GridSize get gridSize => switch (length) {
        4 => GridSize.four,
        6 => GridSize.six,
        _ => GridSize.nine,
      };

  String get pronunciation => transliterate(word);

  /// Numeric puzzle grade to pair with this word so the result plays at
  /// [effective]; null if the word is too hard for that difficulty.
  DifficultyGrade? numericGradeFor(DifficultyGrade effective) {
    final i = effective.index - lookAlikePairs;
    return i < 0 ? null : DifficultyGrade.values[i];
  }
}

/// Hidden words, loaded from assets/words/words.json at startup.
/// Only words that pass the word rules and are not disabled are playable.
class WordBank {
  WordBank._();

  static List<WordEntry> _all = const [];
  static WordList? _list;

  static void load(String rawJson) {
    final list = WordList.parse(rawJson);
    _list = list;
    _all = [
      for (final r in list.playable)
        if (_theme(r.theme) case final t?) WordEntry(r, t),
    ];
  }

  static bool get isLoaded => _list != null;

  static WordTheme? _theme(String key) {
    for (final t in WordTheme.values) {
      if (t.name == key) return t;
    }
    return null;
  }

  static List<WordEntry> get all => _all;

  static WordEntry? byId(String id) {
    for (final w in _all) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Is [fidel] (in order) a different playable word?
  static WordEntry? matching(List<String> fidel) {
    final key = fidel.join();
    for (final w in _all) {
      if (w.fidel.join() == key) return w;
    }
    return null;
  }

  static List<WordEntry> forSize(GridSize size, {WordTheme? theme}) => [
        for (final w in _all)
          if (w.gridSize == size && (theme == null || w.theme == theme)) w,
      ];

  /// Words usable for a puzzle of [size] played at [grade].
  static List<WordEntry> forPuzzle(GridSize size, DifficultyGrade grade,
      {WordTheme? theme}) => [
        for (final w in forSize(size, theme: theme))
          if (w.numericGradeFor(grade) != null) w,
      ];

  static List<WordEntry> forTheme(WordTheme theme) {
    final list = [for (final w in _all) if (w.theme == theme) w];
    list.sort((a, b) => a.length.compareTo(b.length));
    return list;
  }
}
