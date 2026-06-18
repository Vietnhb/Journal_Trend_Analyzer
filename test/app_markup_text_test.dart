import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/core/widgets/app_markup_text.dart';

void main() {
  testWidgets('renders italic and bold tags as styled spans', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppMarkupText('<i>Italic</i> and <b>bold</b>')),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(AppMarkupText),
        matching: find.byType(RichText),
      ),
    );
    final root = richText.text as TextSpan;
    final spans = _textSpans(root);

    expect(
      spans.singleWhere((span) => span.text == 'Italic').style?.fontStyle,
      FontStyle.italic,
    );
    expect(
      spans.singleWhere((span) => span.text == 'bold').style?.fontWeight,
      FontWeight.bold,
    );
  });

  testWidgets('converts common MathML subscript into a styled span', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppMarkupText(
          '<mml:msub><mml:mi>MoS</mml:mi><mml:mi>2</mml:mi></mml:msub>',
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byType(AppMarkupText),
        matching: find.byType(RichText),
      ),
    );
    final root = richText.text as TextSpan;
    final spans = _textSpans(root);
    final subscript = spans.singleWhere((span) => span.text == '2');

    expect(subscript.style?.fontFeatures, const [FontFeature.subscripts()]);
    expect(find.textContaining('<mml:'), findsNothing);
  });
}

List<TextSpan> _textSpans(TextSpan root) {
  final result = <TextSpan>[];

  void visit(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text != null) result.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child);
    }
  }

  visit(root);
  return result;
}
