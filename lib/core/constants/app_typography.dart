import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Roboto';

  static TextTheme textTheme(TextTheme? base) {
    final theme = base ?? Typography.material2021().black;
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -1.2,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -0.9,
      ),
      displaySmall: theme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: -0.7,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.18,
        letterSpacing: -0.6,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.35,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.2,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.15,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.05,
      ),
      titleSmall: theme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: theme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.05,
      ),
      bodyMedium: theme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0.1,
      ),
      bodySmall: theme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.15,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.15,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: 0.25,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.35,
      ),
    );
  }
}
