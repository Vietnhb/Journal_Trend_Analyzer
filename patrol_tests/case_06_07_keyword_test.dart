import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 6 - Keywords navigation displays statistics', (
    $,
  ) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(#topic_keyword_item_1).scrollTo();

    expect($('Most Frequent & Trending Keywords'), findsOneWidget);
    expect($(#topic_keyword_item_1), findsOneWidget);
  });

  patrolTest('Test Case 7 - Keyword details display analytics', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_keywords).tap();
    await $(#topic_keyword_item_1).scrollTo().tap();
    await $(
      'Keyword Detail',
    ).waitUntilVisible(timeout: const Duration(seconds: 60));

    expect($('Publication Trend'), findsOneWidget);
    final detailScroll = find.byKey(const Key('keyword_detail_scroll'));
    final authorsSection = find.byKey(const Key('keyword_top_authors'));
    for (var attempt = 0; attempt < 8; attempt++) {
      if (authorsSection.hitTestable().evaluate().isNotEmpty) break;
      await $.tester.drag(detailScroll, const Offset(0, -700));
      await $.pump(const Duration(milliseconds: 120));
    }
    await $(
      #keyword_top_authors,
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('Top Authors'), findsOneWidget);
  });
}
