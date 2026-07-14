import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/main.dart' as app;
import 'package:patrol/patrol.dart';

Future<void> launchApplication(PatrolIntegrationTester $) async {
  final widget = await app.createJournalTrendAnalyzerApp();
  await $.pumpWidget(widget);
  await $.pumpAndTrySettle(timeout: const Duration(seconds: 3));
}

Future<void> ensureAuthenticated(PatrolIntegrationTester $) async {
  if (!$(#google_sign_in_button).exists) return;

  await _signInWithGoogle($);

  final permissionDialogVisible = await $.platformAutomator.mobile
      .isPermissionDialogVisible(timeout: const Duration(seconds: 3));
  if (permissionDialogVisible) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
    // Let Android finish dismissing the native dialog before the Dart test
    // completes. Ending immediately after a native command can make Patrol's
    // runner report a failure with a null Dart exception.
    await $.pumpAndTrySettle(timeout: const Duration(seconds: 3));
  }

  await $(
    #topic_search_field,
  ).waitUntilVisible(timeout: const Duration(seconds: 10));
}

Future<void> _signInWithGoogle(PatrolIntegrationTester $) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    await $(#google_sign_in_button).tap();
    await $.platformAutomator.tap(
      Selector(resourceId: 'com.google.android.gms:id/container', instance: 0),
    );
    try {
      await $(
        #topic_search_field,
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      return;
    } catch (_) {
      if (!$(#google_sign_in_button).exists || attempt == 1) rethrow;
    }
  }
}

Future<void> selectTopic(
  PatrolIntegrationTester $, {
  String query = 'machine learning',
}) async {
  await ensureAuthenticated($);
  await $(#nav_home).tap();
  await $(#topic_search_field).enterText(query);
  for (var attempt = 0; attempt < 2; attempt++) {
    await $(#topic_search_button).tap();
    try {
      await $(
        'Related Publications',
      ).waitUntilExists(timeout: const Duration(seconds: 60));
      return;
    } catch (_) {
      if (attempt == 1) rethrow;
      await $.pump(const Duration(seconds: 3));
    }
  }
}

Future<void> searchJournal(
  PatrolIntegrationTester $, {
  String query = 'Nature',
}) async {
  await ensureAuthenticated($);
  await $(#nav_journals).tap();
  await $(#journal_search_field).enterText(query);
  await $(#journal_search_button).tap();
  await $(
    #journal_item_1,
  ).waitUntilVisible(timeout: const Duration(seconds: 60));
}
