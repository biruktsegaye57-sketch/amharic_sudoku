import 'package:sudoku_core/sudoku_core.dart' show toGeezNumeral;

/// Ethiopian (Ge'ez) calendar conversion.
///
/// Uses the Julian Day Number method. The Ethiopian year has twelve 30-day
/// months plus Pagume (5 days, 6 in a leap year).
class EthiopicDate {
  const EthiopicDate(this.year, this.month, this.day);

  final int year;

  /// 1..13 (13 = Pagume).
  final int month;
  final int day;

  static const _epoch = 1723856; // JDN of 1 Meskerem 1 (Amete Mihret)

  static const monthNames = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
    'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ',
  ];

  static const monthNamesLatin = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit',
    'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
  ];

  String get monthName => monthNames[month - 1];

  /// "ጥቅምት 9", or "ጥቅምት ፱" with Ge'ez numerals.
  String label({bool geez = false}) => '$monthName ${num(day, geez: geez)}';

  /// "ጥቅምት 2019" / "ጥቅምት ፳፻፲፱".
  String monthYear({bool geez = false}) => '$monthName ${num(year, geez: geez)}';

  static String num(int n, {bool geez = false}) => geez ? toGeezNumeral(n) : '$n';

  /// Days in this month.
  int get monthLength => month == 13 ? ((year + 1) % 4 == 0 ? 6 : 5) : 30;

  factory EthiopicDate.fromGregorian(DateTime date) {
    final jdn = _gregorianToJdn(date.year, date.month, date.day);
    final r = (jdn - _epoch) % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - _epoch) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    final month = n ~/ 30 + 1;
    final day = n % 30 + 1;
    return EthiopicDate(year, month, day);
  }

  DateTime toGregorian() {
    final jdn = _epoch + 365 + 365 * (year - 1) + year ~/ 4 + 30 * month + day - 31;
    return _jdnToGregorian(jdn);
  }

  EthiopicDate get firstOfMonth => EthiopicDate(year, month, 1);

  EthiopicDate addMonths(int delta) {
    var m = month - 1 + delta;
    var y = year;
    while (m < 0) {
      m += 13;
      y--;
    }
    while (m >= 13) {
      m -= 13;
      y++;
    }
    return EthiopicDate(y, m + 1, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is EthiopicDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$monthName $day, $year';

  static int _gregorianToJdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
  }

  static DateTime _jdnToGregorian(int jdn) {
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - 146097 * b ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = 100 * b + d - 4800 + m ~/ 10;
    return DateTime(year, month, day);
  }
}

const _gMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Oct 16"
String shortGregorian(DateTime d) => '${_gMonths[d.month - 1]} ${d.day}';

/// "Oct 16, 2026"
String longGregorian(DateTime d) => '${shortGregorian(d)}, ${d.year}';

/// Date-only key, e.g. "2026-10-16".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// mm:ss (or h:mm:ss past an hour).
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
