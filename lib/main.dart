import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'presentation/widgets/app_bottom_nav_shell.dart';

void main() {
  runApp(const JournalTrendAnalyzerApp());
}

class JournalTrendAnalyzerApp extends StatelessWidget {
  const JournalTrendAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    );

    return MaterialApp(
      title: 'Journal Trend Analyzer',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme(baseTheme.textTheme),
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: AppColors.primary,
          error: AppColors.danger,
        ),
      ),
      home: const AppBottomNavShell(),
    );
  }
}
