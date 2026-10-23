import 'package:flutter/material.dart';
import 'gs_colors.dart';

/// Font families. Inter is the UI family; Ethiopic glyphs fall back to Noto
/// Sans Ethiopic. Board and keypad fidel use Noto Serif Ethiopic.
class GsFonts {
  GsFonts._();
  static const ui = 'Inter';
  static const ethiopic = 'NotoSansEthiopic';
  static const fidel = 'NotoSerifEthiopic';
  static const fallback = [ethiopic];
}

/// Typography from the design system (sizes / line heights).
class GsText {
  GsText._();

  static TextStyle _s(double size, double height, FontWeight w) => TextStyle(
        fontFamily: GsFonts.ui,
        fontFamilyFallback: GsFonts.fallback,
        fontSize: size,
        height: height / size,
        fontWeight: w,
      );

  static final display = _s(30, 36, FontWeight.w700);
  static final headline = _s(22, 28, FontWeight.w400);
  static final title = _s(22, 28, FontWeight.w600);
  static final titleSmall = _s(18, 24, FontWeight.w600);
  static final body = _s(14, 20, FontWeight.w400);
  static final bodyStrong = _s(14, 20, FontWeight.w600);
  static final label = _s(13, 16, FontWeight.w600);
  static final caption = _s(12, 16, FontWeight.w400);
  static final micro = _s(10, 14, FontWeight.w400);
  static final timer = _s(15, 20, FontWeight.w400)
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Fidel shown as content (words, reveal card) — Ethiopic first.
  static TextStyle fidel(double size, {FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: GsFonts.fidel,
        fontFamilyFallback: const [GsFonts.ethiopic, GsFonts.ui],
        fontSize: size,
        height: 1.2,
        fontWeight: weight,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData build(GsColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.gold,
      onSecondary: c.ink,
      error: c.error,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkSecondary,
      outline: c.outline,
      outlineVariant: c.outline,
      primaryContainer: c.tonal,
      onPrimaryContainer: c.onTonal,
      secondaryContainer: c.navIndicator,
      onSecondaryContainer: c.ink,
      surfaceContainerHighest: c.sunken,
      surfaceContainerHigh: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
    );
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final buttonText = GsText.body.copyWith(fontWeight: FontWeight.w400);
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: GsFonts.ui,
      fontFamilyFallback: GsFonts.fallback,
      extensions: [c],
      textTheme: TextTheme(
        displaySmall: GsText.display,
        headlineSmall: GsText.headline,
        titleLarge: GsText.title,
        titleMedium: GsText.titleSmall,
        titleSmall: GsText.bodyStrong,
        bodyLarge: GsText.body,
        bodyMedium: GsText.body,
        bodySmall: GsText.caption,
        labelLarge: GsText.label,
        labelMedium: GsText.caption,
        labelSmall: GsText.micro,
      ).apply(bodyColor: c.ink, displayColor: c.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        titleTextStyle: GsText.headline.copyWith(color: c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.outline,
          disabledForegroundColor: c.inkDisabled,
          minimumSize: const Size.fromHeight(40),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.outline),
          backgroundColor: c.surface,
          minimumSize: const Size.fromHeight(40),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: buttonText,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.inkSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.sunken),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.inkSecondary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.inkSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.brightness == Brightness.dark ? c.surface : c.sunken,
        indicatorColor: c.navIndicator,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          GsText.caption.copyWith(color: c.ink, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.ink)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.toast,
        contentTextStyle: GsText.body.copyWith(color: c.onToast),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.outline,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
