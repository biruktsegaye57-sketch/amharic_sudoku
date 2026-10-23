import 'dart:convert';

import 'word_rules.dart';

/// One entry of assets/words/words.json.
class WordRecord {
  const WordRecord({
    required this.id,
    required this.word,
    required this.theme,
    required this.meaningEn,
    required this.meaningAm,
    this.source = '',
    this.status = 'needs_review',
    this.reviewers = const [],
    this.disabled = false,
  });

  final String id;

  /// Word or phrase with its spacing (spaces are dropped in the grid).
  final String word;
  final String theme;
  final String meaningEn;
  final String meaningAm;
  final String source;

  /// 'needs_review' or 'approved'.
  final String status;
  final List<String> reviewers;

  /// Kill switch for a word reported as wrong after release.
  final bool disabled;

  List<String> get fidel => wordFidel(word);
  int get length => fidel.length;
  bool get approved => status == 'approved' && reviewers.length >= 2;

  factory WordRecord.fromJson(Map<String, dynamic> j) => WordRecord(
        id: j['id'] as String,
        word: j['word'] as String,
        theme: j['theme'] as String,
        meaningEn: (j['meaning_en'] as String?) ?? '',
        meaningAm: (j['meaning_am'] as String?) ?? '',
        source: (j['source'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'needs_review',
        reviewers: ((j['reviewers'] as List?) ?? const []).cast<String>(),
        disabled: (j['disabled'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'theme': theme,
        'meaning_en': meaningEn,
        'meaning_am': meaningAm,
        'source': source,
        'status': status,
        'reviewers': reviewers,
        'disabled': disabled,
      };
}

class WordList {
  WordList({required this.themes, required this.words});

  /// theme key → {'en': …, 'am': …}
  final Map<String, Map<String, String>> themes;
  final List<WordRecord> words;

  factory WordList.parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return WordList(
      themes: {
        for (final e in ((j['themes'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as Map).cast<String, String>(),
      },
      words: [
        for (final w in (j['words'] as List))
          WordRecord.fromJson((w as Map).cast()),
      ],
    );
  }

  /// Words that may appear in puzzles.
  List<WordRecord> get playable => [
        for (final w in words)
          if (!w.disabled && WordRules.check(w.word).isEmpty) w,
      ];

  /// Every problem in the list, as "id: message".
  List<String> validate() {
    final out = <String>[];
    final ids = <String>{};
    final spellings = <String, String>{};
    for (final w in words) {
      if (!ids.add(w.id)) out.add('${w.id}: duplicate id');
      final key = w.fidel.join();
      final prev = spellings[key];
      if (prev != null) out.add('${w.id}: same fidel sequence as $prev');
      spellings[key] = w.id;
      for (final p in WordRules.check(w.word)) {
        out.add('${w.id} ${w.word}: $p');
      }
      if (!themes.containsKey(w.theme)) out.add('${w.id}: unknown theme "${w.theme}"');
      if (w.meaningEn.trim().isEmpty) out.add('${w.id}: missing English meaning');
      if (w.meaningAm.trim().isEmpty) out.add('${w.id}: missing Amharic meaning');
      if (w.status == 'approved' && w.reviewers.length < 2) {
        out.add('${w.id}: approved needs two reviewers');
      }
      if (!const ['approved', 'needs_review'].contains(w.status)) {
        out.add('${w.id}: unknown status "${w.status}"');
      }
    }
    return out;
  }
}
