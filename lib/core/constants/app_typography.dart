import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Roboto';

  static TextTheme textTheme(TextTheme? base) {
    final theme = base ?? const TextTheme();
    return theme.copyWith(
      titleLarge: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
    );
  }
}
