import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/core/constants/app_text_sanitizer.dart';

void main() {
  group('AppTextSanitizer', () {
    test('removes regular HTML tags without joining words', () {
      expect(
        AppTextSanitizer.clean(
          '<i>Ab initio</i>molecular dynamics for liquid metals',
        ),
        'Ab initio molecular dynamics for liquid metals',
      );
    });

    test('removes namespaced MathML tags', () {
      expect(
        AppTextSanitizer.clean(
          'Atomically Thin <mml:math xmlns:mml="http://www.w3.org/1998/'
          'Math/MathML" display="inline"><mml:msub><mml:mi>MoS</mml:mi>'
          '<mml:mi>2</mml:mi></mml:msub></mml:math>',
        ),
        'Atomically Thin MoS 2',
      );
    });

    test('removes subscript tags and decodes entities', () {
      expect(
        AppTextSanitizer.clean(
          'Piezoelectric β-In <sub>2</sub>Se <sub>3</sub> &amp; Devices',
        ),
        'Piezoelectric β-In 2 Se 3 & Devices',
      );
    });

    test('removes encoded HTML tags', () {
      expect(
        AppTextSanitizer.clean('&amp;lt;i&amp;gt;Encoded&amp;lt;/i&amp;gt;'),
        'Encoded',
      );
    });
  });
}
