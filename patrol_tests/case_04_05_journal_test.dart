import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 4 - Journals tab shows journal statistics', ($) async {
    await launchApplication($);
    await searchJournal($);

    expect($('Journal Search Results'), findsOneWidget);
    expect($(#journal_item_1), findsOneWidget);
  });

  patrolTest('Test Case 5 - Journal detail is displayed', ($) async {
    await launchApplication($);
    await searchJournal($);
    await $(#journal_item_1).tap();
    await $(
      #journal_analysis,
    ).waitUntilExists(timeout: const Duration(seconds: 60));

    expect($('Journal profile and performance indicators.'), findsOneWidget);
    expect($('Total works'), findsOneWidget);
    expect($('Citations'), findsOneWidget);
  });
}
