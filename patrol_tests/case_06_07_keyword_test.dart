import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 6 - Keywords tab shows keyword rankings', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(#topic_keyword_item_1).scrollTo();

    expect($('Most Frequent & Trending Keywords'), findsOneWidget);
    expect($(#topic_keyword_item_1), findsOneWidget);
  });

  patrolTest('Test Case 7 - Keyword detail is displayed', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(#topic_keyword_item_1).scrollTo().tap();
    await $(
      'Keyword Detail',
    ).waitUntilVisible(timeout: const Duration(seconds: 60));

    expect($('Publication Trend'), findsOneWidget);
    await $(#keyword_top_authors).scrollTo(step: 500, maxScrolls: 50);
    expect($('Top Authors'), findsOneWidget);
  });
}
