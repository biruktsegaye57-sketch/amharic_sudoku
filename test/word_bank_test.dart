import 'dart:io';

import 'package:amharic_sudoku/core/constants/word_bank.dart';
import 'package:amharic_sudoku/core/utils/ethiopic_calendar.dart';
import 'package:amharic_sudoku/services/audio.dart';
import 'package:amharic_sudoku/services/reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_core/sudoku_core.dart';

void main() {
  final list = WordList.parse(File('assets/words/words.json').readAsStringSync());

  group('Word data source (assets/words/words.json)', () {
    test('validates with no problems', () {
      expect(list.validate(), isEmpty);
    });

    test('every playable word follows the word rules', () {
      for (final w in WordBank.all) {
        expect(WordRules.check(w.word), isEmpty, reason: '${w.id} ${w.word}');
        expect(w.meaning, isNotEmpty);
        expect(w.meaningAm, isNotEmpty);
      }
      expect(WordBank.all.length, list.playable.length);
    });

    test('every theme and size has words; 9×9 has daily words', () {
      for (final t in WordTheme.values) {
        expect(WordBank.forTheme(t), isNotEmpty, reason: t.name);
      }
      for (final s in GridSize.values) {
        expect(WordBank.forSize(s), isNotEmpty);
      }
      expect(WordBank.forPuzzle(GridSize.nine, DifficultyGrade.medium), isNotEmpty);
    });

    test('Easy never uses a word with look-alike pairs', () {
      for (final s in GridSize.values) {
        for (final w in WordBank.forPuzzle(s, DifficultyGrade.easy)) {
          expect(w.lookAlikePairs, 0, reason: w.word);
        }
      }
    });
  });

  group('WordRules', () {
    test('requirement examples pass', () {
      for (final w in ['ዶሮ ወጥ', 'እንጀራ በላ', 'ጎበዝ ተማሪ ናችሁ']) {
        expect(WordRules.check(w), isEmpty, reason: w);
      }
    });

    test('rejects repeats, same family, homophones and bad lengths', () {
      expect(WordRules.check('አዲስ አበባ'), isNotEmpty); // አ repeats
      expect(WordRules.check('ሰሱ ለሉ'), isNotEmpty); // same family
      expect(WordRules.check('ሀሐ ለመ'), isNotEmpty); // homophones
      expect(WordRules.check('ታሪካዊት ጎንደር'), isNotEmpty); // ታ / ት
      expect(WordRules.check('ጅብ ከሄደ ውሻ ጮኸ'), isNotEmpty); // ሄ / ኸ
      expect(WordRules.check('ጎንደር'), isEmpty);
      expect(WordRules.check('ጎንደርበ'), isNotEmpty); // 5 fidel
      expect(WordRules.check('ናብ ር ዝ'), isEmpty);
    });

    test('look-alike pairs raise the grade', () {
      expect(WordRules.lookAlikePairs('ጎበዝ ተማሪ ናችሁ'), 1); // ተ / ቸ
      expect(WordRules.lookAlikePairs('ዶሮ ወጥ'), 0);
      final w = WordBank.byId('s9a')!;
      expect(w.numericGradeFor(DifficultyGrade.easy), isNull);
      expect(w.numericGradeFor(DifficultyGrade.medium), DifficultyGrade.easy);
    });
  });

  group('EthiopicDate', () {
    test('known conversions', () {
      expect(EthiopicDate.fromGregorian(DateTime(2026, 10, 19)), const EthiopicDate(2019, 2, 9));
      expect(EthiopicDate.fromGregorian(DateTime(2026, 10, 11)), const EthiopicDate(2019, 2, 1));
      expect(EthiopicDate.fromGregorian(DateTime(2026, 9, 11)), const EthiopicDate(2019, 1, 1));
      expect(EthiopicDate.fromGregorian(DateTime(2024, 1, 19)), const EthiopicDate(2016, 5, 10));
      expect(const EthiopicDate(2019, 2, 1).toGregorian(), DateTime(2026, 10, 11));
      expect(const EthiopicDate(2019, 2, 9).label(geez: true), 'ጥቅምት ፱');
      expect(const EthiopicDate(2019, 2, 1).monthYear(geez: true), 'ጥቅምት ፳፻፲፱');
    });

    test('round trip over several years', () {
      var d = DateTime(2023, 1, 1);
      for (int i = 0; i < 1500; i++) {
        expect(EthiopicDate.fromGregorian(d).toGregorian(), d);
        d = d.add(const Duration(days: 1));
      }
    });
  });

  test('TTS romanisation an English voice can read', () {
    expect(ttsRomanize('ጎበዝ ተማሪ ናችሁ'), 'gobez temari nachhu');
    expect(ttsRomanize('ዶሮ ወጥ'), 'doro wet');
  });

  test('daily reminder: today 19:00, else tomorrow', () {
    final morning = DateTime(2026, 10, 19, 9);
    expect(Reminders.nextTime(morning, solvedToday: false), DateTime(2026, 10, 19, 19));
    expect(Reminders.nextTime(morning, solvedToday: true), DateTime(2026, 10, 20, 19));
    expect(Reminders.nextTime(DateTime(2026, 10, 19, 20), solvedToday: false),
        DateTime(2026, 10, 20, 19));
  });
}
