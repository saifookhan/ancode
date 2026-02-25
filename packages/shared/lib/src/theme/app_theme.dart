import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Outfit',
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
      );
}
