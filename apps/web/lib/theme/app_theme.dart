import 'package:flutter/material.dart';
import 'package:shared/shared.dart' show AppColors, AppFonts;

export 'package:shared/shared.dart' show AppColors;

/// Full theme for web (shared AppColors)
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.family,
        colorScheme: ColorScheme.light(
          primary: AppColors.bluUniverso,
          onPrimary: AppColors.biancoOttico,
          secondary: AppColors.azzurroCiano,
          onSecondary: AppColors.biancoOttico,
          surface: AppColors.biancoOttico,
          onSurface: AppColors.bluUniverso,
          outline: AppColors.bluPolvere,
          tertiary: AppColors.verdeCosmico,
        ),
        textTheme: _textTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.biancoOttico,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.bluPolvere, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: AppColors.bluPolvere.withOpacity(0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            side: const BorderSide(color: AppColors.bluPolvere),
          ),
        ),
      ).copyWith(
        textTheme: _textTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            side: const BorderSide(color: AppColors.bluPolvere),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.family,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.verdeCosmico,
          onPrimary: AppColors.bluUniverso,
          secondary: AppColors.azzurroCiano,
          surface: AppColors.bluUniverso,
          onSurface: AppColors.biancoOttico,
          outline: AppColors.verdeCosmico,
          tertiary: AppColors.verdeCosmico,
        ),
        scaffoldBackgroundColor: AppColors.bluUniverso,
        textTheme: _textTheme.apply(
          bodyColor: AppColors.biancoOttico,
          displayColor: AppColors.biancoOttico,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.biancoOttico,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.verdeCosmico),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: AppColors.verdeCosmico.withOpacity(0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.verdeCosmico, width: 2),
          ),
        ),
      ).copyWith(
        textTheme: _textTheme.apply(
          bodyColor: AppColors.biancoOttico,
          displayColor: AppColors.biancoOttico,
        ),
      );

  static TextTheme get _textTheme => const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w800, fontSize: 34, letterSpacing: 0.2),
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: 0.2,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        bodySmall: TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
}
