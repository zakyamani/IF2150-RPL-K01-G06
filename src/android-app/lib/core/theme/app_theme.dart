import 'package:flutter/material.dart';

import 'brand.dart';

ThemeData appTheme() {
  final colors = ColorScheme.fromSeed(seedColor: Brand.green).copyWith(
    primary: Brand.green,
    onPrimary: Colors.white,
    surface: Brand.paper,
    onSurface: Brand.ink,
    onSurfaceVariant: Brand.muted,
    primaryContainer: Brand.pale,
    onPrimaryContainer: Brand.ink,
    outline: Brand.line,
    outlineVariant: Brand.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lato',
    colorScheme: colors,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: const TextStyle(
      fontFamily: 'Liberation Serif',
      fontSize: 36,
      height: 1.18,
      color: Brand.ink,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'Liberation Serif',
      fontSize: 32,
      height: 1.18,
      color: Brand.ink,
    ),
    headlineSmall: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: Brand.ink,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.36,
      color: Brand.ink,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: Brand.ink,
    ),
    bodyLarge: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 16,
      height: 1.5,
      color: Brand.ink,
    ),
    bodyMedium: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 14,
      height: 1.5,
      color: Brand.ink,
    ),
    labelLarge: const TextStyle(
      fontFamily: 'Lato',
      fontSize: 12,
      height: 1.4,
      color: Brand.muted,
    ),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Brand.line),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: Brand.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: Brand.paper,
      foregroundColor: Brand.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 24,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Brand.line),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: text.bodyMedium?.copyWith(color: Brand.muted),
      floatingLabelStyle: text.labelLarge,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Brand.green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Lato',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Brand.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Lato',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Lato',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Brand.paper,
      selectedColor: Brand.pale,
      checkmarkColor: Brand.green,
      showCheckmark: false,
      labelStyle: text.bodyMedium,
      side: const BorderSide(color: Brand.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(color: Brand.line, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Brand.pale,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Lato',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? Brand.green
              : Brand.muted,
        ),
      ),
    ),
  );
}
