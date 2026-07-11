import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 11 - Logout returns to Login', ($) async {
    await launchApplication($);
    await ensureAuthenticated($);

    await $(#nav_profile).tap();
    await $(#logout_button).scrollTo().tap();
    await $(
      #google_sign_in_button,
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    expect($(#google_sign_in_button), findsOneWidget);
  });
}
