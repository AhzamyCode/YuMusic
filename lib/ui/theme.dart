import 'package:flutter/material.dart';

/// Tampilan Yumusic: permukaan netral, satu warna aksen, tanpa bayangan.
const accent = Color(0xFFFF6B4A);
const _accentOnLight = Color(0xFFE2472A);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? accent : _accentOnLight;
  final background = dark ? const Color(0xFF0E0E10) : const Color(0xFFFAFAFA);
  final raised = dark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
  final higher = dark ? const Color(0xFF222226) : const Color(0xFFF0F0F2);
  final text = dark ? const Color(0xFFF4F4F5) : const Color(0xFF111113);
  final muted = dark ? const Color(0xFF9B9BA3) : const Color(0xFF6B6B73);
  final line = dark ? const Color(0xFF2A2A2F) : const Color(0xFFE4E4E8);

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primary.withValues(alpha: dark ? 0.18 : 0.12),
    onPrimaryContainer: primary,
    secondaryContainer: higher,
    onSecondaryContainer: text,
    surface: background,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: background,
    surfaceContainerLow: raised,
    surfaceContainer: raised,
    surfaceContainerHigh: higher,
    surfaceContainerHighest: higher,
    outline: line,
    outlineVariant: line,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final textTheme = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: base.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? text : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? text : muted,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      titleTextStyle: textTheme.bodyLarge
          ?.copyWith(color: text, fontWeight: FontWeight.w500),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted),
      iconColor: muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: raised,
      modalBackgroundColor: raised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2C2C31) : const Color(0xFF222226),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: text,
      inactiveTrackColor: line,
      thumbColor: text,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: line,
    ),
  );
}
