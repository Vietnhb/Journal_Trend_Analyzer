import 'package:flutter/material.dart';

/// Central color tokens used by the application.
///
/// Keep colors here semantic rather than tying them to one screen. Theme-aware
/// widgets should prefer [ColorScheme]; these constants are useful for charts,
/// branded gradients, and semantic data visualisation.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF315FD5);
  static const Color primaryLight = Color(0xFF6F8EF0);
  static const Color primarySoft = Color(0xFFE8EEFF);
  static const Color accent = Color(0xFF7357D9);
  static const Color accentSoft = Color(0xFFF0ECFF);

  // Backgrounds
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F7);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF0D1321);
  static const Color darkSurface = Color(0xFF151D2E);
  static const Color darkSurfaceVariant = Color(0xFF202A3D);
  static const Color darkBorder = Color(0xFF303B50);

  // Text
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF5E6A7D);
  static const Color textHint = Color(0xFF8B96A8);

  // Semantic
  static const Color success = Color(0xFF14805E);
  static const Color danger = Color(0xFFD14343);
  static const Color warning = Color(0xFFB86E00);
  static const Color info = Color(0xFF1677C8);

  // Divider / Border
  static const Color borderLight = Color(0xFFDDE2EB);
  static const Color divider = Color(0xFFE9ECF2);

  // Gold / Silver / Bronze for rankings
  static const Color gold = Color(0xFFE4A11B);
  static const Color silver = Color(0xFF8894A7);
  static const Color bronze = Color(0xFFB56B35);

  /// Accessible, visually distinct colors for categorical charts.
  static const List<Color> chartPalette = <Color>[
    primary,
    accent,
    Color(0xFF168A8A),
    Color(0xFFE07A45),
    Color(0xFF3A8F5C),
    Color(0xFFC24F8A),
  ];

  static const List<Color> heatmapScale = <Color>[
    Color(0xFFE8EEFF),
    Color(0xFFCAD7FF),
    Color(0xFF99B2F7),
    Color(0xFF6388E8),
    primary,
  ];

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
