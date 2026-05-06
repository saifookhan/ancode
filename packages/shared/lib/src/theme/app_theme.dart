import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

export 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppFonts.family,
        colorScheme: ColorScheme.light(
          primary: AppColors.bluUniverso,
          onPrimary: AppColors.biancoOttico,
          secondary: AppColors.azzurroCiano,
          surface: AppColors.biancoOttico,
          onSurface: AppColors.bluUniverso,
          outline: AppColors.bluPolvere,
          tertiary: AppColors.verdeCosmico,
        ),
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
        textTheme: _textTheme.apply(fontFamily: AppFonts.family),
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
          fontFamily: AppFonts.family,
          bodyColor: AppColors.biancoOttico,
          displayColor: AppColors.biancoOttico,
        ),
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 34, letterSpacing: 0.2),
        headlineLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: 0.2),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        headlineSmall: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: const TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
        bodyMedium: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        bodySmall: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );
}
