import 'package:sudoku_core/sudoku_core.dart';

import '../../core/utils/ethiopic_calendar.dart';

class LessonItem {
  const LessonItem(this.glyph, this.label, this.detail, {String? say})
      : _say = say;
  final String glyph;
  final String label;
  final String detail;
  final String? _say;

  /// What an English voice reads when no Amharic voice is installed.
  String get say => _say ?? label;
}

const _numberWords = [
  'and', 'hulet', 'sost', 'arat', 'amist', 'sidist', 'sebat', 'simint', 'zetegn',
];

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.explain,
    this.sound,
  });

  final String prompt;
  final List<String> options;
  final String answer;

  /// Shown after answering.
  final String explain;

  /// Spoken prompt (shown as text until audio is bundled).
  final String? sound;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.meta,
    required this.icon,
    required this.quizName,
    required this.heading,
    required this.intro,
    required this.items,
    required this.tipTitle,
    required this.tip,
    required this.questions,
    required this.badge,
    required this.doneTitle,
    required this.doneBody,
  });

  final String id;
  final String title;
  final String meta;
  final String icon;
  final String quizName;
  final String heading;
  final String intro;
  final List<LessonItem> items;
  final String tipTitle;
  final String tip;
  final List<QuizQuestion> questions;
  final String badge;
  final String doneTitle;
  final String doneBody;
}

List<LessonItem> _family(String base) {
  final fam = kFidelFamilies.firstWhere((f) => f.first == base);
  const names = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh'];
  return [
    for (int i = 0; i < 7; i++)
      LessonItem(fam[i], fidelSound(fam[i], explicitSixth: true),
          'The ${names[i]} vowel form'),
  ];
}

final List<Lesson> kLessons = [
  Lesson(
    id: 'vowels',
    title: 'Reading the 7 vowel forms',
    meta: '7 forms · 3 min',
    icon: 'በ',
    quizName: 'VOWEL FORMS',
    heading: 'One family. Seven sounds.',
    intro: 'Each fidel changes its shape to carry a different vowel. Meet the በ family.',
    items: _family('በ'),
    tipTitle: 'A small shape, a new sound',
    tip: 'Compare በ and ቦ. Look at the small loop on the right of ቦ — it helps you spot “bo”.',
    questions: const [
      QuizQuestion(
        prompt: 'Which one is ‘bo’?',
        sound: 'bo',
        options: ['በ', 'ቡ', 'ባ', 'ቦ'],
        answer: 'ቦ',
        explain: 'ቦ is “bo”, the seventh vowel form. The small loop helps you recognise it.',
      ),
      QuizQuestion(
        prompt: 'Which one is ‘bu’?',
        sound: 'bu',
        options: ['ቡ', 'ቢ', 'ብ', 'ቤ'],
        answer: 'ቡ',
        explain: 'ቡ is “bu”, the second form: a short stroke on the right side.',
      ),
      QuizQuestion(
        prompt: 'Which one is ‘ba’?',
        sound: 'ba',
        options: ['በ', 'ባ', 'ቦ', 'ቢ'],
        answer: 'ባ',
        explain: 'ባ is “ba”, the fourth form: the right leg is shortened.',
      ),
      QuizQuestion(
        prompt: 'Which one is ‘bi’?',
        sound: 'bi',
        options: ['ቤ', 'ብ', 'ቢ', 'ቡ'],
        answer: 'ቢ',
        explain: 'ቢ is “bi”, the third form: a foot on the lower right.',
      ),
    ],
    badge: 'FIDEL READER',
    doneTitle: 'You’re a fidel reader',
    doneBody: 'You’ve learned the 7 vowel forms of በ. A small step that opens up new words.',
  ),
  const Lesson(
    id: 'alike',
    title: 'Letters that look alike',
    meta: 'Notice the details · 4 min',
    icon: 'ሀ ሐ',
    quizName: 'LOOK-ALIKES',
    heading: 'Same sound, different letter.',
    intro: 'Amharic keeps a few historic letters that sound the same today. Spot them on your board.',
    items: [
      LessonItem('ሀ', 'h', 'ሀ, ሐ and ኀ all sound like “h”'),
      LessonItem('ሐ', 'h', 'An older “h” — see it in ሐረር'),
      LessonItem('ሰ', 's', 'ሰ and ሠ both sound like “s”'),
      LessonItem('ሠ', 's', 'The historic “s”, with a crown on top'),
      LessonItem('አ', 'a', 'አ and ዐ both carry a vowel'),
      LessonItem('ዐ', 'a', 'Round like an “O”, read like አ'),
      LessonItem('ጸ', "ts'", 'ጸ and ፀ share one sound'),
    ],
    tipTitle: 'Read by sound, play by shape',
    tip: 'On the board every shape is its own symbol. ሰ and ሠ sound alike but never replace each other.',
    questions: [
      QuizQuestion(
        prompt: 'Which letter sounds like ሀ?',
        options: ['ለ', 'ሐ', 'መ', 'ረ'],
        answer: 'ሐ',
        explain: 'ሐ sounds like ሀ: both are “h”.',
      ),
      QuizQuestion(
        prompt: 'Which letter sounds like ሰ?',
        options: ['ሠ', 'ሸ', 'ቀ', 'ዘ'],
        answer: 'ሠ',
        explain: 'ሠ is the historic “s”. ሸ is “sh”, a different sound.',
      ),
      QuizQuestion(
        prompt: 'Which letter sounds like አ?',
        options: ['ኦ', 'ዐ', 'ወ', 'የ'],
        answer: 'ዐ',
        explain: 'ዐ carries a vowel, just like አ.',
      ),
      QuizQuestion(
        prompt: 'Which letter sounds like ጸ?',
        options: ['ፀ', 'ጠ', 'ጨ', 'ፈ'],
        answer: 'ፀ',
        explain: "ፀ and ጸ are both “ts'”.",
      ),
    ],
    badge: 'SHARP EYE',
    doneTitle: 'You have a sharp eye',
    doneBody: 'You can tell look-alike letters apart. The board will feel calmer now.',
  ),
  Lesson(
    id: 'numerals',
    title: 'Ge’ez numerals 1 to 9',
    meta: 'Nine familiar values · 3 min',
    icon: '፩ ፪',
    quizName: 'GE’EZ NUMERALS',
    heading: 'Nine numbers, one script.',
    intro: 'Ge’ez numerals are used for dates, prices and Classic Sudoku. Each one has a line above and below.',
    items: [
      for (int i = 0; i < 9; i++)
        LessonItem(kGeezNumerals[i], '${i + 1}', 'Ge’ez numeral for ${i + 1}',
            say: _numberWords[i]),
    ],
    tipTitle: 'Same values, a different script',
    tip: 'Classic mode can show ፩–፱ instead of 1–9. The puzzle logic does not change.',
    questions: const [
      QuizQuestion(
        prompt: 'Which numeral is 5?',
        options: ['፫', '፭', '፰', '፪'],
        answer: '፭',
        explain: '፭ is five.',
      ),
      QuizQuestion(
        prompt: 'Which numeral is 1?',
        options: ['፩', '፯', '፱', '፬'],
        answer: '፩',
        explain: '፩ is one.',
      ),
      QuizQuestion(
        prompt: 'Which numeral is 9?',
        options: ['፮', '፱', '፪', '፰'],
        answer: '፱',
        explain: '፱ is nine.',
      ),
      QuizQuestion(
        prompt: 'Which numeral is 3?',
        options: ['፬', '፫', '፯', '፩'],
        answer: '፫',
        explain: '፫ is three.',
      ),
    ],
    badge: 'NUMBER READER',
    doneTitle: 'You can count in Ge’ez',
    doneBody: 'Try a Classic puzzle with Ge’ez numerals to practise.',
  ),
  Lesson(
    id: 'dates',
    title: 'Reading dates',
    meta: 'Days, months & years · 4 min',
    icon: '፲፱',
    quizName: 'DATES',
    heading: 'Thirteen months.',
    intro: 'The Ethiopian calendar has twelve months of 30 days and a short thirteenth month, ጳጉሜ.',
    items: [
      for (int i = 0; i < 13; i++)
        LessonItem(EthiopicDate.monthNames[i], EthiopicDate.monthNamesLatin[i],
            'Month ${i + 1} of the Ethiopian year'),
    ],
    tipTitle: 'Your daily puzzle uses this calendar',
    tip: 'The Daily calendar shows each Ethiopian month next to the Gregorian dates it covers.',
    questions: const [
      QuizQuestion(
        prompt: 'Which month comes first?',
        options: ['ጥር', 'መስከረም', 'ሰኔ', 'ግንቦት'],
        answer: 'መስከረም',
        explain: 'መስከረም (Meskerem) begins the Ethiopian year in September.',
      ),
      QuizQuestion(
        prompt: 'Which is the short 13th month?',
        options: ['ነሐሴ', 'ጳጉሜ', 'ሐምሌ', 'ኅዳር'],
        answer: 'ጳጉሜ',
        explain: 'ጳጉሜ (Pagume) has 5 days, or 6 in a leap year.',
      ),
      QuizQuestion(
        prompt: 'Which month comes after መስከረም?',
        options: ['ጥቅምት', 'የካቲት', 'ሚያዝያ', 'ታኅሣሥ'],
        answer: 'ጥቅምት',
        explain: 'ጥቅምት (Tikimt) is the second month.',
      ),
      QuizQuestion(
        prompt: 'How many days are in ጥቅምት?',
        options: ['28', '30', '31', '29'],
        answer: '30',
        explain: 'Every month except ጳጉሜ has exactly 30 days.',
      ),
    ],
    badge: 'DATE READER',
    doneTitle: 'You can read the calendar',
    doneBody: 'Meskerem to Pagume: the thirteen months of the year are yours.',
  ),
];

Lesson? lessonById(String id) {
  for (final l in kLessons) {
    if (l.id == id) return l;
  }
  return null;
}
