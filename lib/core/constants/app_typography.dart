import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Roboto';

  static TextTheme textTheme(TextTheme? base) {
    final theme = base ?? const TextTheme();
    return theme.copyWith(
      displaySmall: theme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: theme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: theme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: theme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: theme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: theme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}
