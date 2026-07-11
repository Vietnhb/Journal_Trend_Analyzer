import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/main.dart' as app;
import 'package:patrol/patrol.dart';

Future<void> launchApplication(PatrolIntegrationTester $) async {
  final widget = await app.createJournalTrendAnalyzerApp();
  await $.pumpWidgetAndSettle(widget);
}

Future<void> ensureAuthenticated(PatrolIntegrationTester $) async {
  if (!$(#google_sign_in_button).exists) return;

  await _signInWithGoogle($);

  final permissionDialogVisible = await $.platformAutomator.mobile
      .isPermissionDialogVisible(timeout: const Duration(seconds: 3));
  if (permissionDialogVisible) {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
  }
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
  await $(#topic_search_button).tap();
  await $(
    'Related Publications',
  ).waitUntilExists(timeout: const Duration(seconds: 60));
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
