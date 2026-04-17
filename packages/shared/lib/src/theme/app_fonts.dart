import 'package:flutter/material.dart';

/// Registered in [pubspec.yaml] as bundled rounded sans (see fonts/NOTICE.txt).
abstract final class AppFonts {
  AppFonts._();

  static const String family = 'KitRounded';
}

/// KIT Rounded roles (weights map to bundled KitRounded-* assets).
abstract final class AppTypography {
  AppTypography._();

  static TextStyle titleExtraBold({
    required Color color,
    required double fontSize,
    double height = 1,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.normal,
        fontSize: fontSize,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextStyle subtitleSemiBold({
    required Color color,
    required double fontSize,
    double height = 1.1,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextStyle bodyRegular({
    required Color color,
    required double fontSize,
    double height = 1.2,
  }) =>
      TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        height: height,
        color: color,
      );

  static TextStyle bodySemiBoldItalic({
    required Color color,
    required double fontSize,
    double height = 1.2,
  }) =>
      TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        fontSize: fontSize,
        height: height,
        color: color,
      );

  static TextStyle captionLight({
    required Color color,
    required double fontSize,
    double height = 1.25,
  }) =>
      TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w300,
        fontSize: fontSize,
        height: height,
        color: color,
      );
}
