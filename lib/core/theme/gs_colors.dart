import 'package:flutter/material.dart';

/// Board / app theme choice (Settings → Appearance).
enum GsThemeMode { light, dark, parchment, system }

/// Ge'ez Sudoku design-system colours (Figma "01 / Visual foundation").
///
/// Where Dark or Parchment do not define a state colour, the Light token is
/// inherited, as the design system specifies.
@immutable
class GsColors extends ThemeExtension<GsColors> {
  const GsColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.sunken,
    required this.ink,
    required this.inkSecondary,
    required this.inkDisabled,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.tonal,
    required this.onTonal,
    required this.outline,
    required this.gold,
    required this.goldSoft,
    required this.wordBand,
    required this.glow,
    required this.boardThin,
    required this.boardThick,
    required this.cell,
    required this.given,
    required this.entry,
    required this.error,
    required this.errorBg,
    required this.selected,
    required this.peer,
    required this.sameFidel,
    required this.guessed,
    required this.guessedInk,
    required this.key,
    required this.keyPressed,
    required this.navIndicator,
    required this.toast,
    required this.onToast,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color sunken;
  final Color ink;
  final Color inkSecondary;
  final Color inkDisabled;
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color tonal;
  final Color onTonal;
  final Color outline;
  final Color gold;
  final Color goldSoft;
  final Color wordBand;
  final Color glow;
  final Color boardThin;
  final Color boardThick;
  final Color cell;
  final Color given;
  final Color entry;
  final Color error;
  final Color errorBg;
  final Color selected;
  final Color peer;
  final Color sameFidel;
  final Color guessed;
  final Color guessedInk;
  final Color key;
  final Color keyPressed;
  final Color navIndicator;
  final Color toast;
  final Color onToast;

  static const light = GsColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFEEF1F5),
    ink: Color(0xFF1D2433),
    inkSecondary: Color(0xFF5E6678),
    inkDisabled: Color(0xFFA9B0BD),
    primary: Color(0xFF2F4A9E),
    primaryPressed: Color(0xFF243A7D),
    onPrimary: Color(0xFFFFFFFF),
    tonal: Color(0xFFEAF0FF),
    onTonal: Color(0xFF2F4A9E),
    outline: Color(0xFFD3D8E2),
    gold: Color(0xFFC99A2E),
    goldSoft: Color(0xFFFFF3D1),
    wordBand: Color(0xFFFFF6DD),
    glow: Color(0xFFF2C14E),
    boardThin: Color(0xFFD3D8E2),
    boardThick: Color(0xFF1D2433),
    cell: Color(0xFFFFFFFF),
    given: Color(0xFF1D2433),
    entry: Color(0xFF2F4A9E),
    error: Color(0xFFD64545),
    errorBg: Color(0xFFFCE8E8),
    selected: Color(0xFFC9D8FF),
    peer: Color(0xFFEAF0FF),
    sameFidel: Color(0xFFB5C8FA),
    guessed: Color(0xFFE7F5EC),
    guessedInk: Color(0xFF2E7D4F),
    key: Color(0xFFEAF0FF),
    keyPressed: Color(0xFFB5C8FA),
    navIndicator: Color(0xFFDCE4FA),
    toast: Color(0xFF1D2433),
    onToast: Color(0xFFFFFFFF),
  );

  static const dark = GsColors(
    brightness: Brightness.dark,
    background: Color(0xFF121620),
    surface: Color(0xFF1B2130),
    sunken: Color(0xFF161B27),
    ink: Color(0xFFE8ECF4),
    inkSecondary: Color(0xFFA3ABBD),
    inkDisabled: Color(0xFF5E6678),
    primary: Color(0xFF3A56B0),
    primaryPressed: Color(0xFF2F4A9E),
    onPrimary: Color(0xFFFFFFFF),
    tonal: Color(0xFF232B40),
    onTonal: Color(0xFF8FA8F0),
    outline: Color(0xFF2C3446),
    gold: Color(0xFFC99A2E),
    goldSoft: Color(0xFFFFF3D1),
    wordBand: Color(0xFF3A3220),
    glow: Color(0xFFF2C14E),
    boardThin: Color(0xFF2C3446),
    boardThick: Color(0xFFC9D1E0),
    cell: Color(0xFF1B2130),
    given: Color(0xFFE8ECF4),
    entry: Color(0xFF8FA8F0),
    error: Color(0xFFFF7A7A),
    errorBg: Color(0xFF3A1F24),
    selected: Color(0xFF2F3E66),
    peer: Color(0xFF222B40),
    sameFidel: Color(0xFF34477A),
    guessed: Color(0xFFE7F5EC),
    guessedInk: Color(0xFF2E7D4F),
    key: Color(0xFF222B40),
    keyPressed: Color(0xFF34477A),
    navIndicator: Color(0xFF2F3E66),
    toast: Color(0xFFE8ECF4),
    onToast: Color(0xFF121620),
  );

  static const parchment = GsColors(
    brightness: Brightness.light,
    background: Color(0xFFF3E7CF),
    surface: Color(0xFFFBF4E4),
    sunken: Color(0xFFEFE0C2),
    ink: Color(0xFF2E2013),
    inkSecondary: Color(0xFF6E5638),
    inkDisabled: Color(0xFFB8A27E),
    primary: Color(0xFF7A3B12),
    primaryPressed: Color(0xFF5E2D0E),
    onPrimary: Color(0xFFFFFFFF),
    tonal: Color(0xFFEBD6A8),
    onTonal: Color(0xFF4A3520),
    outline: Color(0xFFD9C7A3),
    gold: Color(0xFFB8862B),
    goldSoft: Color(0xFFFFF3D1),
    wordBand: Color(0xFFFFF6DD),
    glow: Color(0xFFB8862B),
    boardThin: Color(0xFFD9C7A3),
    boardThick: Color(0xFF4A3520),
    cell: Color(0xFFFBF4E4),
    given: Color(0xFF2E2013),
    entry: Color(0xFF7A3B12),
    error: Color(0xFFD64545),
    errorBg: Color(0xFFFCE8E8),
    selected: Color(0xFFEBD6A8),
    peer: Color(0xFFF3E7CF),
    sameFidel: Color(0xFFE6D2A2),
    guessed: Color(0xFFE7F5EC),
    guessedInk: Color(0xFF2E7D4F),
    key: Color(0xFFEBD6A8),
    keyPressed: Color(0xFFDDBF83),
    navIndicator: Color(0xFFEBD6A8),
    toast: Color(0xFF2E2013),
    onToast: Color(0xFFFBF4E4),
  );

  @override
  GsColors copyWith() => this;

  @override
  GsColors lerp(ThemeExtension<GsColors>? other, double t) =>
      t < 0.5 ? this : (other as GsColors? ?? this);
}

extension GsColorsX on BuildContext {
  GsColors get gs => Theme.of(this).extension<GsColors>()!;
}
