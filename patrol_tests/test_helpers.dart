import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/main.dart' as app;
import 'package:patrol/patrol.dart';

Future<void> launchApplication(PatrolIntegrationTester $) async {
  final widget = await app.createJournalTrendAnalyzerApp();
  await $.pumpWidgetAndSettle(widget);
}

void requireAuthenticated(PatrolIntegrationTester $) {
  if ($(#google_sign_in_button).exists) {
    throw TestFailure(
      'A Google session is required. Run authentication_test.dart first '
      'and keep the Firebase Auth session on the emulator.',
    );
  }
}

Future<void> selectTopic(
  PatrolIntegrationTester $, {
  String query = 'machine learning',
}) async {
  requireAuthenticated($);
  await $(#nav_home).tap();
  await $(#topic_search_field).enterText(query);
  await $(#topic_search_button).tap();
  await $(
    'Related Publications',
  ).waitUntilVisible(timeout: const Duration(seconds: 60));
}
