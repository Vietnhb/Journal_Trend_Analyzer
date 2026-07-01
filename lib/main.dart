import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_typography.dart';
import 'presentation/providers/firebase_provider.dart';
import 'presentation/providers/journal_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/widgets/app_bottom_nav_shell.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final app = await createJournalTrendAnalyzerApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(app);
  } catch (error) {
    runApp(FirebaseSetupErrorApp(error: error.toString()));
  }
}

Future<JournalTrendAnalyzerApp> createJournalTrendAnalyzerApp() async {
  await Firebase.initializeApp();
  final firebaseProvider = FirebaseProvider();
  await firebaseProvider.initialize();
  return JournalTrendAnalyzerApp(firebaseProvider: firebaseProvider);
}

class JournalTrendAnalyzerApp extends StatelessWidget {
  final FirebaseProvider firebaseProvider;

  const JournalTrendAnalyzerApp({super.key, required this.firebaseProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: firebaseProvider),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
      ],
      child: Consumer2<JournalProvider, FirebaseProvider>(
        builder: (context, journalProvider, firebaseProvider, child) {
          return MaterialApp(
            title: 'Journal Trend Analyzer',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: journalProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: firebaseProvider.isAuthenticated
                ? const AppBottomNavShell()
                : const LoginScreen(),
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

class FirebaseSetupErrorApp extends StatelessWidget {
  final String error;

  const FirebaseSetupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase could not be initialized.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(error, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
