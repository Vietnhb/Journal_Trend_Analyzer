import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 1 - Google Sign-In opens Home', ($) async {
    await launchApplication($);

    await ensureAuthenticated($);

    expect($(#topic_search_field), findsOneWidget);
    expect($('Home'), findsWidgets);
  });
}
