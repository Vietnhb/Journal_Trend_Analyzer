import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_admin_web/utils/ui_format.dart';

void main() {
  test('formats byte sizes for admin report summaries', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(10 * 1024 * 1024), '10 MB');
  });

  test('truncates long identifiers without losing both ends', () {
    expect(truncateMiddle('abcdefghijklmnopqrstuvwxyz', keep: 4), 'abcd…wxyz');
    expect(truncateMiddle('short', keep: 4), 'short');
  });

  test('maps audit action codes to Vietnamese labels', () {
    expect(friendlyAction('user.delete'), 'Xóa người dùng');
    expect(friendlyAction('message.broadcast.send'), 'Gửi thông báo hàng loạt');
    expect(friendlyAction('future.action'), 'future.action');
  });
}
