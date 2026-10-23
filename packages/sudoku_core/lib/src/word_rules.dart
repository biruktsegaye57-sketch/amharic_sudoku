import 'fidel_data.dart';

/// Families whose letters sound the same; never mixed in one puzzle.
/// (ኸ is read as "h" in Amharic, so it joins the ሀ group.)
const List<Set<String>> kHomophoneFamilies = [
  {'ሀ', 'ሐ', 'ኀ', 'ኸ'},
  {'ሰ', 'ሠ'},
  {'አ', 'ዐ'},
  {'ጸ', 'ፀ'},
];

/// Derived look-alike families. Allowed together, but each pair present raises
/// the puzzle's difficulty one step.
const List<(String, String)> kLookAlikeFamilies = [
  ('ሰ', 'ሸ'),
  ('ተ', 'ቸ'),
  ('ነ', 'ኘ'),
  ('ከ', 'ኸ'),
  ('በ', 'ቨ'),
];

/// Splits a word or phrase into fidel (spaces dropped).
List<String> wordFidel(String word) => [
      for (final r in word.runes)
        if (r != 0x20) String.fromCharCode(r),
    ];

/// The word rules from the requirements ("Word list and word-safe generation").
class WordRules {
  WordRules._();

  static const sizes = [4, 6, 9];

  /// Problems with [word]; empty if it passes every automatic rule.
  /// [allowSameFamily] is for the optional "Fidel master" pack.
  static List<String> check(String word, {bool allowSameFamily = false}) {
    final problems = <String>[];
    final fidel = wordFidel(word);
    if (!sizes.contains(fidel.length)) {
      problems.add('has ${fidel.length} fidel; needs 4, 6 or 9');
    }
    for (final f in fidel) {
      if (fidelPosition(f) == null) problems.add('"$f" is not a known single fidel');
    }
    if (fidel.toSet().length != fidel.length) problems.add('a fidel repeats');
    final families = [for (final f in fidel) fidelFamily(f)];
    if (!allowSameFamily && families.toSet().length != families.length) {
      final dup = <String>{};
      final seen = <String>{};
      for (int i = 0; i < families.length; i++) {
        if (!seen.add(families[i])) dup.add(families[i]);
      }
      problems.add('two fidel from the same family (${dup.join(', ')})');
    }
    for (final group in kHomophoneFamilies) {
      final present = {for (final f in families) if (group.contains(f)) f};
      if (present.length > 1) {
        problems.add('mixes homophones ${present.join('/')}');
      }
    }
    if (word.trim() != word || word.contains('  ')) {
      problems.add('extra spaces');
    }
    return problems;
  }

  /// Number of derived look-alike family pairs in [word].
  static int lookAlikePairs(String word) {
    final families = {for (final f in wordFidel(word)) fidelFamily(f)};
    int n = 0;
    for (final (a, b) in kLookAlikeFamilies) {
      if (families.contains(a) && families.contains(b)) n++;
    }
    return n;
  }
}
