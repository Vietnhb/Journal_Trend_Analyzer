import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Brand — an electric indigo / cyan pairing built for dense data products.
  static const Color brand = Color(0xFF5B5CEB);
  static const Color brandDeep = Color(0xFF4144C6);
  static const Color accent = Color(0xFF13B8A6);
  static const Color ink = Color(0xFF171923);
  static const Color navigation = Color(0xFF10121B);
  static const Color navigationRaised = Color(0xFF181B27);

  // Semantic
  static const Color success = Color(0xFF10A779);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE34D59);
  static const Color info = Color(0xFF2F8BFF);

  // Light surfaces
  static const Color lightScaffold = Color(0xFFF3F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF7F8FC);
  static const Color lightBorder = Color(0xFFE4E7EF);
  static const Color lightBorderFaint = Color(0xFFF0F2F7);

  // Dark surfaces
  static const Color darkScaffold = Color(0xFF090B11);
  static const Color darkSurface = Color(0xFF12151E);
  static const Color darkSurfaceVariant = Color(0xFF181C28);
  static const Color darkBorder = Color(0xFF292E3D);
  static const Color darkBorderFaint = Color(0xFF202431);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double page = 36;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 11;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 999;
}

abstract final class AppShadows {
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: const Color(0xFF161A2B).withValues(alpha: .045),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF161A2B).withValues(alpha: .025),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: const Color(0xFF161A2B).withValues(alpha: .085),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF161A2B).withValues(alpha: .035),
      blurRadius: 5,
      offset: const Offset(0, 2),
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
    seed: const Color(0xFF8B8DFF),
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

    final generatedScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      error: AppColors.danger,
    );
    final scheme = isDark
        ? generatedScheme.copyWith(
            primary: const Color(0xFFA7A8FF),
            onPrimary: const Color(0xFF111329),
            primaryContainer: const Color(0xFF30336E),
            onPrimaryContainer: const Color(0xFFE2E3FF),
            secondary: const Color(0xFF54D7C7),
            onSecondary: const Color(0xFF00201C),
            secondaryContainer: const Color(0xFF123B38),
            onSecondaryContainer: const Color(0xFFB7F3EA),
            surface: surface,
            onSurface: const Color(0xFFF1F2F8),
            onSurfaceVariant: const Color(0xFFB8BDCC),
            outline: const Color(0xFF484E60),
            outlineVariant: AppColors.darkBorder,
            surfaceContainerLowest: const Color(0xFF080A10),
            surfaceContainerLow: const Color(0xFF0E1119),
            surfaceContainer: AppColors.darkSurface,
            surfaceContainerHigh: AppColors.darkSurfaceVariant,
            surfaceContainerHighest: const Color(0xFF202534),
            error: const Color(0xFFFF6675),
            onError: const Color(0xFF35000A),
          )
        : generatedScheme;

    final baseText = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );

    // Manrope gives headings a distinctive editorial voice while Inter keeps
    // dense controls and data highly legible.
    final headingColor = isDark ? const Color(0xFFF5F6FA) : AppColors.ink;
    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.manrope(
        textStyle: baseText.displayLarge,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
      ),
      displayMedium: GoogleFonts.manrope(
        textStyle: baseText.displayMedium,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
      ),
      displaySmall: GoogleFonts.manrope(
        textStyle: baseText.displaySmall,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      headlineLarge: GoogleFonts.manrope(
        textStyle: baseText.headlineLarge,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: GoogleFonts.manrope(
        textStyle: baseText.headlineMedium,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
      ),
      headlineSmall: GoogleFonts.manrope(
        textStyle: baseText.headlineSmall,
        color: headingColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
      titleLarge: GoogleFonts.manrope(
        textStyle: baseText.titleLarge,
        color: headingColor,
        letterSpacing: -.35,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
      ),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.48),
      bodySmall: baseText.bodySmall?.copyWith(height: 1.45),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      disabledColor: isDark
          ? const Color(0xFF747A8B)
          : scheme.onSurface.withValues(alpha: .38),
      visualDensity: const VisualDensity(horizontal: -.2, vertical: -.2),
      dividerColor: border,
      focusColor: seed.withValues(alpha: .12),
      hoverColor: seed.withValues(alpha: .055),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),

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
        toolbarHeight: 64,
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
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
          horizontal: 15,
          vertical: 14,
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
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: isDark
              ? const Color(0xFF242836)
              : scheme.onSurface.withValues(alpha: .12),
          disabledForegroundColor: isDark
              ? const Color(0xFF858B9C)
              : scheme.onSurface.withValues(alpha: .38),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          elevation: 0,
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
        style:
            OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? const Color(0xFFD9DCE8)
                  : scheme.primary,
              disabledForegroundColor: isDark
                  ? const Color(0xFF747A8B)
                  : scheme.onSurface.withValues(alpha: .38),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: isDark
                        ? const Color(0xFF303646)
                        : border.withValues(alpha: .65),
                  );
                }
                if (states.contains(WidgetState.hovered)) {
                  return BorderSide(
                    color: scheme.primary.withValues(alpha: .8),
                  );
                }
                return BorderSide(color: border);
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return scheme.primary.withValues(alpha: isDark ? .08 : .045);
                }
                return Colors.transparent;
              }),
            ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFFC7CAFF) : scheme.primary,
          disabledForegroundColor: isDark
              ? const Color(0xFF747A8B)
              : scheme.onSurface.withValues(alpha: .38),
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
        backgroundColor: isDark
            ? const Color(0xFF151925)
            : AppColors.lightSurfaceVariant,
        selectedColor: scheme.primary.withValues(alpha: isDark ? .2 : .1),
        disabledColor: isDark
            ? const Color(0xFF11141C)
            : scheme.onSurface.withValues(alpha: .04),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: isDark ? const Color(0xFFD9DAFF) : scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
        checkmarkColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? const Color(0xFF202431) : Colors.transparent;
          }
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(
          color: isDark ? const Color(0xFF9AA0B2) : scheme.outline,
          width: 1.7,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
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
        headingRowHeight: 48,
        dataRowMinHeight: 60,
        dataRowMaxHeight: 76,
        headingRowColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        ),
        headingTextStyle: GoogleFonts.inter(
          color: scheme.onSurfaceVariant,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: scheme.onSurface,
          fontSize: 13.25,
          fontWeight: FontWeight.w400,
        ),
        dividerThickness: .55,
        columnSpacing: 32,
        horizontalMargin: 24,
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return isDark
                ? Colors.white.withValues(alpha: .03)
                : AppColors.brand.withValues(alpha: .035);
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
