import 'package:flutter/material.dart';

/// ANCODE brand colors – pixel-perfect match to design
class AppColors {
  AppColors._();

  /// Dark navy/purple – create screen background, theme primary surfaces
  static const Color bluUniverso = Color(0xFF1F1F47);
  /// Deep navy for pill buttons on white (search landing – almost black blue)
  static const Color bluUniversoDeep = Color(0xFF101523);
  /// Slightly lighter navy for create screen
  static const Color bluUniversoLight = Color(0xFF2C2C54);
  /// Logo and accent blue
  static const Color azzurroCiano = Color(0xFF3682DF);
  /// White
  static const Color biancoOttico = Color(0xFFFFFFFF);
  /// Light green – outlines, shadows, accents
  static const Color verdeCosmico = Color(0xFFB4FF9A);
  /// Solid lime for neubrutalist offset shadows (search landing)
  static const Color limeNeobrut = Color(0xFFD4F97E);
  /// Hard lime “sticker” shadow on create page (white pill controls)
  static const Color limeCreateHard = Color(0xFFC6FF7A);
  /// Softer light green for unselected nav circles
  static const Color verdeCosmicoSoft = Color(0xFFECF9D9);
  /// Dark blue/teal – titles, CERCA text
  static const Color bluPolvere = Color(0xFF1F455A);
  /// Placeholder / grey text
  static const Color placeholderGrey = Color(0xFF888888);
  /// Light lavender – landing title and active search tab (pastel, readable on white)
  static const Color lavanda = Color(0xFFCDBDF2);
  /// Brighter active color for bottom-nav selected bubble
  static const Color navActiveBg = Color(0xFFB39BFF);
  /// Brighter active color for bottom-nav selected label
  static const Color navActiveText = Color(0xFFA489FF);
  /// Inactive bottom-nav icon and label (medium neutral gray)
  static const Color navInactive = Color(0xFFA8A8A8);
}
