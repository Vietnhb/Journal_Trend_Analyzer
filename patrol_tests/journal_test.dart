import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 4 - Journals tab shows journal statistics', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_journals).tap();

    expect($('Journal Contribution Chart'), findsOneWidget);
    expect($(#journal_item_1), findsOneWidget);
  });

  patrolTest('Test Case 5 - Journal detail is displayed', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_journals).tap();
    await $(#journal_item_1).scrollTo().tap();
    await $(
      'Journal Detail',
    ).waitUntilVisible(timeout: const Duration(seconds: 60));

    expect($('Related Publications'), findsOneWidget);
    expect($('Total Citations'), findsOneWidget);
  });
}
