import 'package:flutter/services.dart';
import 'package:sudoku_core/sudoku_core.dart';

/// Sound effects bundled in android/app/src/main/res/raw (synthesised by
/// tool/sounds/make_sounds.py).
enum Sfx { tap, place, note, error, unit, hint, coin, word, win, lose, splash }

/// Plays sound effects and speaks fidel through the native audio channel.
/// Every call is fire-and-forget and silently does nothing where the
/// channel is missing (tests, unsupported platforms).
class GameAudio {
  GameAudio._();

  static const _channel = MethodChannel('geez_sudoku/audio');

  static Future<void> play(Sfx sfx, {double volume = 1}) async {
    try {
      await _channel.invokeMethod('play', {'name': sfx.name, 'volume': volume});
    } on MissingPluginException {
      // No native audio (tests).
    } on PlatformException {
      // Ignore: sound is decoration.
    }
  }

  /// Speaks Amharic [text]. Uses an Amharic voice when the phone has one,
  /// otherwise an English voice reading [ttsRomanize] of the text.
  static Future<void> speak(String text, {String? fallback}) async {
    try {
      await _channel.invokeMethod('speak', {
        'text': text,
        'fallback': (fallback ?? ttsRomanize(text))
            .replaceAll('ä', 'e')
            .replaceAll('ə', 'i')
            .replaceAll("'", ''),
      });
    } on MissingPluginException {
      // No native audio (tests).
    } on PlatformException {
      // Ignore.
    }
  }
}

/// Romanisation that an English voice reads close to Amharic:
/// ä → e, no ejective marks, q → k. "ጎበዝ ተማሪ" → "gobez temari".
String ttsRomanize(String text) {
  final sb = StringBuffer();
  for (final word in text.split(' ')) {
    if (sb.isNotEmpty) sb.write(' ');
    for (final r in word.runes) {
      final f = String.fromCharCode(r);
      final s = fidelSound(f);
      sb.write(s == f ? f : s);
    }
  }
  return sb
      .toString()
      .replaceAll('ä', 'e')
      .replaceAll('ə', 'i')
      .replaceAll("'", '')
      .replaceAll('q', 'k');
}
