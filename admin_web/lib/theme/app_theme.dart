import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Brand
  static const Color brand = Color(0xFF2563EB);
  static const Color accent = Color(0xFF7C3AED);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // Light surfaces
  static const Color lightScaffold = Color(0xFFEEF1F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF7F9FC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderFaint = Color(0xFFF1F5F9);

  // Dark surfaces
  static const Color darkScaffold = Color(0xFF07090F);
  static const Color darkSurface = Color(0xFF0F1523);
  static const Color darkSurfaceVariant = Color(0xFF151D2E);
  static const Color darkBorder = Color(0xFF1E2D45);
  static const Color darkBorderFaint = Color(0xFF162035);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double full = 999.0;
}

abstract final class AppShadows {
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .06),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get dialog => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .18),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: .06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // Dark mode equivalents (slightly stronger to compensate for dark bg)
  static List<BoxShadow> get smDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: .24),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get mdDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: .32),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─── Theme builder ────────────────────────────────────────────────────────────

// Keep backward‑compat alias so existing code using AppTheme.danger etc. still works.
abstract final class AppTheme {
  static const Color brand = AppColors.brand;
  static const Color accent = AppColors.accent;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;

  static ThemeData light() => _build(
    brightness: Brightness.light,
    seed: AppColors.brand,
    scaffold: AppColors.lightScaffold,
    surface: AppColors.lightSurface,
    surfaceVariant: AppColors.lightSurfaceVariant,
    border: AppColors.lightBorder,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    seed: const Color(0xFF60A5FA),
    scaffold: AppColors.darkScaffold,
    surface: AppColors.darkSurface,
    surfaceVariant: AppColors.darkSurfaceVariant,
    border: AppColors.darkBorder,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      error: AppColors.danger,
    );

    final baseText = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    // Tighten letter-spacing on display sizes — Inter looks better slightly tighter
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(letterSpacing: -1.5),
      displayMedium: baseText.displayMedium?.copyWith(letterSpacing: -1.0),
      displaySmall: baseText.displaySmall?.copyWith(letterSpacing: -0.8),
      headlineLarge: baseText.headlineLarge?.copyWith(letterSpacing: -0.6),
      headlineMedium: baseText.headlineMedium?.copyWith(letterSpacing: -0.5),
      headlineSmall: baseText.headlineSmall?.copyWith(letterSpacing: -0.4),
      titleLarge: baseText.titleLarge?.copyWith(
        letterSpacing: -0.2,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.55),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.standard,
      dividerColor: border,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        toolbarHeight: 52,
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        // Note: actual shadows applied in SectionCard widget via BoxDecoration
        // because CardTheme doesn't support shadow + border simultaneously well.
        clipBehavior: Clip.antiAlias,
      ),

      // ── Input ───────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .6),
          fontSize: 13.5,
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Chip ────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        width: 420,
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // ── DataTable ────────────────────────────────────────────────────────────
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 44,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        ),
        headingTextStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        dividerThickness: 0.5,
        columnSpacing: 24,
        horizontalMargin: 20,
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return isDark
                ? Colors.white.withValues(alpha: .03)
                : Colors.black.withValues(alpha: .02);
          }
          return null;
        }),
      ),

      // ── NavigationRail ───────────────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: .1),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 20),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: border, thickness: 0.5, space: 1),

      // ── Popup Menu ───────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border),
        ),
        textStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── ListTile ─────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),

      // ── Page Transitions ─────────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
