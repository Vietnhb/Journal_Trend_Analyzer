import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 2 - Topic search displays publications', ($) async {
    await launchApplication($);
    await selectTopic($);

    expect($('Related Publications'), findsOneWidget);
    expect($(#publication_item), findsWidgets);
  });

  patrolTest('Test Case 3 - Publication detail is displayed', ($) async {
    await launchApplication($);
    await selectTopic($);

    await $(#publication_item).first.scrollTo().tap();
    await $('Journal Publication').waitUntilVisible();

    expect($('Journal Publication'), findsOneWidget);
    expect($('Abstract'), findsOneWidget);
  });
}
