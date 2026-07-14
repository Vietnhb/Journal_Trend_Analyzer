import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 10 - Remote Config values are displayed', ($) async {
    await launchApplication($);
    await ensureAuthenticated($);
    await $(#nav_profile).tap();
    await $(#lab_tools_section).scrollTo().tap();
    await $(#remote_config_values).scrollTo();

    expect($(#remote_config_values), findsOneWidget);
    expect(find.textContaining('max_journals:'), findsOneWidget);
    expect(find.textContaining('max_keywords:'), findsOneWidget);
  });
}
