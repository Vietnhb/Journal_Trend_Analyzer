import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/theme/app_theme.dart';
import 'package:journal_trend_admin_web/widgets/admin_widgets.dart';

void main() {
  testWidgets('metric card renders the supplied operational data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: MetricCard(
            label: 'Total users',
            value: '42',
            detail: '5 new accounts',
            icon: Icons.people_outline,
          ),
        ),
      ),
    );

    expect(find.text('TOTAL USERS'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('5 new accounts'), findsOneWidget);
  });

  testWidgets('typed confirmation stays disabled until exact text is entered', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final future = showTypedConfirmation(
      context: hostContext,
      title: 'Publish changes?',
      description: 'These changes will apply to the mobile app.',
      confirmationText: 'PUBLISH',
      actionLabel: 'Confirm',
    );
    await tester.pumpAndSettle();

    var confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm'),
    );
    expect(confirmButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'PUBLISH');
    await tester.pump();
    confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm'),
    );
    expect(confirmButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(await future, isTrue);
  });

  testWidgets('simple confirmation only requires an explicit button click', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final future = showConfirmation(
      context: hostContext,
      title: 'Delete report?',
      description: 'This action cannot be undone.',
      actionLabel: 'Delete report',
      danger: true,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    final confirm = find.widgetWithText(FilledButton, 'Delete report');
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(await future, isTrue);
  });
}
