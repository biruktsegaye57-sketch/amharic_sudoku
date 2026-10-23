// Fidel (Ethiopic script character) data for Ge'ez Sudoku.
// All fidel listed in traditional ሀለሐ (Ge'ez alphabetical) order.

/// Consonant families in ሀለሐ order. Each entry is the seven vowel orders
/// (ä, u, i, a, e, ə, o) of one consonant.
const List<List<String>> kFidelFamilies = [
  ['ሀ', 'ሁ', 'ሂ', 'ሃ', 'ሄ', 'ህ', 'ሆ'],
  ['ለ', 'ሉ', 'ሊ', 'ላ', 'ሌ', 'ል', 'ሎ'],
  ['ሐ', 'ሑ', 'ሒ', 'ሓ', 'ሔ', 'ሕ', 'ሖ'],
  ['መ', 'ሙ', 'ሚ', 'ማ', 'ሜ', 'ም', 'ሞ'],
  ['ሠ', 'ሡ', 'ሢ', 'ሣ', 'ሤ', 'ሥ', 'ሦ'],
  ['ረ', 'ሩ', 'ሪ', 'ራ', 'ሬ', 'ር', 'ሮ'],
  ['ሰ', 'ሱ', 'ሲ', 'ሳ', 'ሴ', 'ስ', 'ሶ'],
  ['ሸ', 'ሹ', 'ሺ', 'ሻ', 'ሼ', 'ሽ', 'ሾ'],
  ['ቀ', 'ቁ', 'ቂ', 'ቃ', 'ቄ', 'ቅ', 'ቆ'],
  ['በ', 'ቡ', 'ቢ', 'ባ', 'ቤ', 'ብ', 'ቦ'],
  ['ቨ', 'ቩ', 'ቪ', 'ቫ', 'ቬ', 'ቭ', 'ቮ'],
  ['ተ', 'ቱ', 'ቲ', 'ታ', 'ቴ', 'ት', 'ቶ'],
  ['ቸ', 'ቹ', 'ቺ', 'ቻ', 'ቼ', 'ች', 'ቾ'],
  ['ኀ', 'ኁ', 'ኂ', 'ኃ', 'ኄ', 'ኅ', 'ኆ'],
  ['ነ', 'ኑ', 'ኒ', 'ና', 'ኔ', 'ን', 'ኖ'],
  ['ኘ', 'ኙ', 'ኚ', 'ኛ', 'ኜ', 'ኝ', 'ኞ'],
  ['አ', 'ኡ', 'ኢ', 'ኣ', 'ኤ', 'እ', 'ኦ'],
  ['ከ', 'ኩ', 'ኪ', 'ካ', 'ኬ', 'ክ', 'ኮ'],
  ['ኸ', 'ኹ', 'ኺ', 'ኻ', 'ኼ', 'ኽ', 'ኾ'],
  ['ወ', 'ዉ', 'ዊ', 'ዋ', 'ዌ', 'ው', 'ዎ'],
  ['ዐ', 'ዑ', 'ዒ', 'ዓ', 'ዔ', 'ዕ', 'ዖ'],
  ['ዘ', 'ዙ', 'ዚ', 'ዛ', 'ዜ', 'ዝ', 'ዞ'],
  ['ዠ', 'ዡ', 'ዢ', 'ዣ', 'ዤ', 'ዥ', 'ዦ'],
  ['የ', 'ዩ', 'ዪ', 'ያ', 'ዬ', 'ይ', 'ዮ'],
  ['ደ', 'ዱ', 'ዲ', 'ዳ', 'ዴ', 'ድ', 'ዶ'],
  ['ጀ', 'ጁ', 'ጂ', 'ጃ', 'ጄ', 'ጅ', 'ጆ'],
  ['ገ', 'ጉ', 'ጊ', 'ጋ', 'ጌ', 'ግ', 'ጎ'],
  ['ጠ', 'ጡ', 'ጢ', 'ጣ', 'ጤ', 'ጥ', 'ጦ'],
  ['ጨ', 'ጩ', 'ጪ', 'ጫ', 'ጬ', 'ጭ', 'ጮ'],
  ['ጰ', 'ጱ', 'ጲ', 'ጳ', 'ጴ', 'ጵ', 'ጶ'],
  ['ጸ', 'ጹ', 'ጺ', 'ጻ', 'ጼ', 'ጽ', 'ጾ'],
  ['ፀ', 'ፁ', 'ፂ', 'ፃ', 'ፄ', 'ፅ', 'ፆ'],
  ['ፈ', 'ፉ', 'ፊ', 'ፋ', 'ፌ', 'ፍ', 'ፎ'],
  ['ፐ', 'ፑ', 'ፒ', 'ፓ', 'ፔ', 'ፕ', 'ፖ'],
];

/// Latin consonant for each family in [kFidelFamilies] (same order).
/// Empty string = glottal / vowel carrier (አ, ዐ).
const List<String> _kFamilyConsonants = [
  'h', 'l', 'h', 'm', 's', 'r', 's', 'sh', 'q', 'b', 'v', 't', 'ch', 'h',
  'n', 'ny', '', 'k', 'h', 'w', '', 'z', 'zh', 'y', 'd', 'j', 'g', "t'",
  "ch'", "p'", "ts'", "ts'", 'f', 'p',
];

/// Latin vowel for each of the seven orders.
const List<String> kVowelOrders = ['ä', 'u', 'i', 'a', 'e', 'ə', 'o'];

/// All valid fidel characters in ሀለሐ order.
/// Used for keypad ordering and word validation.
final List<String> kAllFidelInOrder = [
  for (final family in kFidelFamilies) ...family,
];

/// Ge'ez numeral symbols (1–9).
const List<String> kGeezNumerals = ['፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];

/// Arabic digit strings (classic mode).
const List<String> kArabicDigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

/// Returns (familyIndex, order) for a fidel, or null if unknown.
(int, int)? fidelPosition(String fidel) {
  final i = kAllFidelInOrder.indexOf(fidel);
  if (i < 0) return null;
  return (i ~/ 7, i % 7);
}

/// Returns the family (base consonant) of a fidel character.
/// E.g. ሀ, ሁ, ሂ, ሃ, ሄ, ህ, ሆ all belong to family 'ሀ'.
String fidelFamily(String fidel) {
  final pos = fidelPosition(fidel);
  return pos == null ? fidel : kFidelFamilies[pos.$1][0];
}

/// Returns true if two fidel belong to the same consonant family.
bool sameFidelFamily(String a, String b) => fidelFamily(a) == fidelFamily(b);

/// Homophone groups — fidel that sound the same.
const List<List<String>> kHomophoneGroups = [
  ['ሀ', 'ሐ', 'ኀ', 'ሃ', 'ሓ', 'ኃ'],
  ['ሰ', 'ሠ'],
  ['አ', 'ዐ'],
  ['ጸ', 'ፀ'],
];

/// Returns true if two fidel are homophones of each other.
bool areHomophones(String a, String b) {
  for (final group in kHomophoneGroups) {
    if (group.contains(a) && group.contains(b)) return true;
  }
  return false;
}

/// Sort a list of fidel into ሀለሐ order. Unknown symbols keep their relative
/// order after the known ones.
List<String> sortFidelInOrder(List<String> fidels) {
  int key(String f) {
    final i = kAllFidelInOrder.indexOf(f);
    return i < 0 ? 1 << 20 : i;
  }

  final copy = List<String>.from(fidels);
  copy.sort((a, b) => key(a).compareTo(key(b)));
  return copy;
}

/// Approximate Latin pronunciation of one fidel.
///
/// The sixth order is usually unvoiced, so by default it is written without a
/// vowel (ች → "ch"). Pass [explicitSixth] to get the lesson spelling ("bə").
String fidelSound(String fidel, {bool explicitSixth = false}) {
  final pos = fidelPosition(fidel);
  if (pos == null) return fidel;
  final consonant = _kFamilyConsonants[pos.$1];
  final order = pos.$2;
  if (consonant.isEmpty) {
    // Vowel carriers: አ ኡ ኢ ኣ ኤ እ ኦ.
    const carrier = ['a', 'u', 'i', 'a', 'e', 'i', 'o'];
    return carrier[order];
  }
  if (order == 5 && !explicitSixth) return consonant;
  return consonant + kVowelOrders[order];
}

/// Approximate Latin transliteration of an Amharic word or phrase.
String transliterate(String text) {
  final sb = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(ch == ' ' ? ' ' : fidelSound(ch));
  }
  return sb.toString();
}

const _geezOnes = ['', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];
const _geezTens = ['', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺'];

/// Writes 1..99 999 999 in Ge'ez numerals (2019 → ፳፻፲፱, 100 → ፻).
String toGeezNumeral(int n) {
  if (n <= 0) return '$n';
  // Split into base-100 groups, lowest first.
  final groups = <int>[];
  for (var v = n; v > 0; v ~/= 100) {
    groups.add(v % 100);
  }
  final sb = StringBuffer();
  for (int i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    final isLowest = i == 0;
    // A leading ፩ is dropped before ፻ / ፼ (100 = ፻, 10 000 = ፼).
    if (g != 0 && !(g == 1 && !isLowest)) {
      sb.write(_geezTens[g ~/ 10]);
      sb.write(_geezOnes[g % 10]);
    }
    if (!isLowest && (g != 0 || i % 2 == 0)) {
      sb.write(i.isOdd ? '፻' : '፼');
    }
  }
  return sb.toString();
}
