import 'package:intl/intl.dart';

import '../core/api/api_exception.dart';
import '../core/auth/admin_auth_service.dart';

final _number = NumberFormat.decimalPattern('en_US');
final _dateTime = DateFormat('MMM d, yyyy, h:mm a', 'en_US');
final _date = DateFormat('MMM d', 'en_US');
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
  'user.update' => 'Update user',
  'user.role.grant_admin' => 'Grant admin access',
  'user.role.revoke_admin' => 'Revoke admin access',
  'user.sessions.revoke' => 'Revoke sessions',
  'user.delete' => 'Delete user',
  'remote_config.update' => 'Publish Remote Config',
  'remote_config.rollback' => 'Roll back Remote Config',
  'report.bulk_delete' => 'Delete reports',
  'report.delete_all' => 'Delete all reports',
  'report.delete' => 'Delete report',
  'message.test.send' => 'Send test notification',
  'message.broadcast.send' => 'Send broadcast notification',
  'message.campaign.send' => 'Send notification campaign',
  'message.campaign.schedule' => 'Schedule notification campaign',
  'message.campaign.cancel' => 'Cancel scheduled campaign',
  'bootstrap.role.grant_admin' => 'Grant initial admin access',
  'bootstrap.role.revoke_admin' => 'Revoke bootstrap access',
  _ => action,
};

String errorText(Object error) {
  final message = switch (error) {
    ApiException(:final userMessage) => userMessage,
    AdminAuthException(:final userMessage) => userMessage,
    _ => null,
  };
  if (message != null && message.trim().isNotEmpty) return message;
  return error.toString().replaceFirst('Exception: ', '');
}
