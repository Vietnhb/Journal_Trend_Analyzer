import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 10 - Remote Config values are displayed', ($) async {
    await launchApplication($);
    requireAuthenticated($);
    await $(#nav_profile).tap();
    await $(#lab_tools_section).scrollTo().tap();
    await $(#remote_config_values).scrollTo();

    expect($(#remote_config_values), findsOneWidget);
    expect($('max_journals: 10 | max_keywords: 12'), findsOneWidget);
  });
}
