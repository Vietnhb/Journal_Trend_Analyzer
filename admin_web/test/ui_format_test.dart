import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/utils/ui_format.dart';

void main() {
  test('formats byte sizes for admin report summaries', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(10 * 1024 * 1024), '10 MB');
  });

  test('formats numbers and dates with the English (US) locale', () {
    expect(formatNumber(1234.5), '1,234.5');
    expect(formatDateTime('2026-07-23T10:20:00'), 'Jul 23, 2026, 10:20 AM');
    expect(formatChartDate('2026-07-23'), 'Jul 23');
  });

  test('truncates long identifiers without losing both ends', () {
    expect(truncateMiddle('abcdefghijklmnopqrstuvwxyz', keep: 4), 'abcd…wxyz');
    expect(truncateMiddle('short', keep: 4), 'short');
  });

  test('maps audit action codes to English labels', () {
    expect(friendlyAction('user.delete'), 'Delete user');
    expect(
      friendlyAction('message.broadcast.send'),
      'Send broadcast notification',
    );
    expect(friendlyAction('future.action'), 'future.action');
  });
}
