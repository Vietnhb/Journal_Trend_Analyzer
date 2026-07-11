import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 8 - Profile information is displayed', ($) async {
    await launchApplication($);
    await ensureAuthenticated($);
    await $(#nav_profile).tap();

    expect($(#profile_screen), findsOneWidget);
    await $(#export_pdf_button).scrollTo();
    expect($('REPORTS'), findsOneWidget);
    await $(#notification_center_button).scrollTo();
    expect($('Notifications'), findsOneWidget);
    await $(#logout_button).scrollTo();
    expect($('Sign Out'), findsOneWidget);
  });
}
