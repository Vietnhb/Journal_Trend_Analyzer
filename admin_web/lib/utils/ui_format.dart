import 'package:intl/intl.dart';

final _number = NumberFormat.decimalPattern('vi_VN');
final _dateTime = DateFormat('dd/MM/yyyy, HH:mm', 'vi_VN');
final _date = DateFormat('dd/MM', 'vi_VN');
final _currency = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 2,
);

String formatNumber(num? value) => value == null ? '—' : _number.format(value);

String formatCurrency(num? value) =>
    value == null ? '—' : _currency.format(value);

String formatBytes(num? bytes) {
  if (bytes == null) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value >= 10 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
}

String formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : _dateTime.format(parsed.toLocal());
}

String formatChartDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : _date.format(parsed.toLocal());
}

String truncateMiddle(String value, {int keep = 8}) {
  if (value.length <= keep * 2 + 1) return value;
  return '${value.substring(0, keep)}…${value.substring(value.length - keep)}';
}

String initials(String? name, String? email) {
  final value = (name?.trim().isNotEmpty == true ? name : email)?.trim() ?? '?';
  final words = value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    return String.fromCharCodes(words.first.runes.take(2)).toUpperCase();
  }
  final first = String.fromCharCode(words.first.runes.first);
  final last = String.fromCharCode(words.last.runes.first);
  return '$first$last'.toUpperCase();
}

String friendlyAction(String action) => switch (action) {
  'user.update' => 'Cập nhật người dùng',
  'user.role.grant_admin' => 'Cấp quyền Admin',
  'user.role.revoke_admin' => 'Thu hồi quyền Admin',
  'user.sessions.revoke' => 'Thu hồi phiên đăng nhập',
  'user.delete' => 'Xóa người dùng',
  'remote_config.update' => 'Xuất bản Remote Config',
  'remote_config.rollback' => 'Khôi phục Remote Config',
  'report.bulk_delete' => 'Xóa nhiều báo cáo',
  'report.delete_all' => 'Xóa toàn bộ báo cáo',
  'report.delete' => 'Xóa báo cáo',
  'message.test.send' => 'Gửi thông báo thử',
  'message.broadcast.send' => 'Gửi thông báo hàng loạt',
  'message.campaign.send' => 'Gửi chiến dịch thông báo',
  'message.campaign.schedule' => 'Lên lịch chiến dịch',
  'message.campaign.cancel' => 'Hủy lịch chiến dịch',
  'bootstrap.role.grant_admin' => 'Khởi tạo quyền Admin',
  'bootstrap.role.revoke_admin' => 'Thu hồi quyền khởi tạo',
  _ => action,
};

String errorText(Object error) {
  try {
    final dynamic value = error;
    final String? message = value.userMessage as String?;
    if (message != null && message.trim().isNotEmpty) return message;
  } catch (_) {
    // The exception is not an API exception.
  }
  return error.toString().replaceFirst('Exception: ', '');
}
