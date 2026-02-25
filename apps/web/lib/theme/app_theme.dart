import 'package:flutter/material.dart';
import 'package:shared/shared.dart' show AppColors;

export 'package:shared/shared.dart' show AppColors;

/// Full theme for web (shared AppColors)
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Outfit', // KIT-style geometric sans. To use KIT: add font files to web/fonts/ and @font-face in index.html, then change to 'KIT'
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
        fontFamily: 'Outfit',
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
        headlineLarge: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
}
