import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/core/core.dart';

void main() {
  group('AppFormat', () {
    test('formats common admin values', () {
      expect(AppFormat.number(1234), isNotEmpty);
      expect(AppFormat.bytes(0), '0 B');
      expect(AppFormat.bytes(1536), contains('KB'));
      expect(AppFormat.dateTime('2026-07-23T10:20:00'), '23/07/2026 10:20');
      expect(AppFormat.dateTime('not-a-date'), '—');
    });

    test('creates initials and truncates long identifiers safely', () {
      expect(AppFormat.initials('Nguyễn Văn An'), 'NA');
      expect(AppFormat.initials(null, 'admin@example.com'), 'AD');
      expect(
        AppFormat.truncateMiddle('abcdefghijklmnopqrstuvwxyz', sideLength: 4),
        'abcd…wxyz',
      );
    });
  });
}
