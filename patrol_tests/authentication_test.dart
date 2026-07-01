import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 1 - Google Sign-In opens Home', ($) async {
    await launchApplication($);

    if ($(#google_sign_in_button).exists) {
      await $(#google_sign_in_button).tap();
      await $(
        #topic_search_field,
      ).waitUntilVisible(timeout: const Duration(seconds: 60));
    }

    expect($(#topic_search_field), findsOneWidget);
    expect($('Home'), findsWidgets);
  });

  patrolTest('Test Case 11 - Logout returns to Login', ($) async {
    await launchApplication($);
    requireAuthenticated($);

    await $(#nav_profile).tap();
    await $(#logout_button).scrollTo().tap();
    await $(
      #google_sign_in_button,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    expect($(#google_sign_in_button), findsOneWidget);
  });
}
