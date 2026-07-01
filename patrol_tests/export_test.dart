import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

void main() {
  patrolTest('Test Case 9 - PDF report uploads to Firebase Storage', ($) async {
    await launchApplication($);
    await selectTopic($);
    await $(#nav_profile).tap();
    await $(#export_pdf_button).scrollTo().tap();
    await $(
      'Uploaded report',
    ).waitUntilVisible(timeout: const Duration(seconds: 90));

    expect($('Uploaded report'), findsOneWidget);
    expect($(#uploaded_report_status), findsOneWidget);
  });
}
