import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'presentation/providers/publication_provider.dart';
import 'presentation/widgets/app_bottom_nav_shell.dart';

void main() {
  runApp(const JournalTrendAnalyzerApp());
}

class JournalTrendAnalyzerApp extends StatelessWidget {
  const JournalTrendAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PublicationProvider(),
      child: Consumer<PublicationProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Journal Trend Analyzer',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppBottomNavShell(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: isDark ? const Color(0xFF111827) : AppColors.surface,
      error: AppColors.danger,
      brightness: brightness,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F172A)
          : AppColors.background,
    );

    return baseTheme.copyWith(
      textTheme: AppTypography.textTheme(baseTheme.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.borderLight,
          ),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : AppColors.borderLight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF334155) : AppColors.divider,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: AppTypography.fontFamily,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
    );
  }
}
