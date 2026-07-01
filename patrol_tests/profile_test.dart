import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 8 - Profile information is displayed', ($) async {
    await launchApplication($);
    requireAuthenticated($);
    await $(#nav_profile).tap();

    expect($(#profile_screen), findsOneWidget);
    expect($('Sign Out'), findsOneWidget);
    expect($('Reports'), findsOneWidget);
    expect($('Notifications'), findsOneWidget);
  });
}
