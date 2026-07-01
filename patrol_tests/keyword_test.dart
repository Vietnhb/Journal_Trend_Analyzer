import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 6 - Keywords tab shows keyword rankings', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(
      #keyword_item_1,
    ).waitUntilVisible(timeout: const Duration(seconds: 45));

    expect($('Most Frequent & Trending Keywords'), findsOneWidget);
    expect($(#keyword_item_1), findsOneWidget);
  });

  patrolTest('Test Case 7 - Keyword detail is displayed', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(
      #keyword_item_1,
    ).waitUntilVisible(timeout: const Duration(seconds: 45));
    await $(#keyword_item_1).tap();
    await $(
      'Keyword Detail',
    ).waitUntilVisible(timeout: const Duration(seconds: 60));

    expect($('Publication Trend'), findsOneWidget);
    expect($('Top Authors'), findsOneWidget);
  });
}
