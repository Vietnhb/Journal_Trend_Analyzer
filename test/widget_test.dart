import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:journal_trend_analyzer/main.dart';

void main() {
  testWidgets('app renders bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const JournalTrendAnalyzerApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });
}
