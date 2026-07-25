import 'dart:math' as math;

import 'package:intl/intl.dart';

abstract final class AppFormat {
  static final NumberFormat _integer = NumberFormat.decimalPattern('en_US');
  static final NumberFormat _decimal = NumberFormat('0.#', 'en_US');
  static final DateFormat _dateTime = DateFormat(
    'MMM d, yyyy, h:mm a',
    'en_US',
  );
  static final DateFormat _shortDate = DateFormat('MMM d', 'en_US');
  static const _byteUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

  static String number(num? value) =>
      _integer.format(value != null && value.isFinite ? value : 0);

  static String dateTime(String? value) {
    final parsed = _parseDate(value);
    if (parsed == null) return '—';
    return _dateTime.format(parsed.toLocal());
  }

  static String shortDate(String? value) {
    final parsed = _parseDate(value);
    if (parsed == null) return value?.trim() ?? '';
    return _shortDate.format(parsed.toLocal());
  }

  static String bytes(num? value) {
    final amount = value?.toDouble() ?? 0;
    if (!amount.isFinite || amount <= 0) return '0 B';
    final unitIndex = math.min(
      (math.log(amount) / math.log(1024)).floor(),
      _byteUnits.length - 1,
    );
    final scaled = amount / math.pow(1024, unitIndex);
    final formatted = unitIndex == 0
        ? scaled.round().toString()
        : _decimal.format(scaled);
    return '$formatted ${_byteUnits[unitIndex]}';
  }

  static String initials(String? name, [String? email]) {
    final source = _firstNonEmpty([name, email]) ?? 'A';
    final parts = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final result = parts.length > 1
        ? '${_firstCharacter(parts.first)}${_firstCharacter(parts.last)}'
        : _takeCharacters(parts.first, 2);
    return result.toUpperCase();
  }

  static String truncateMiddle(String value, {int sideLength = 13}) {
    if (sideLength < 1) {
      throw RangeError.range(sideLength, 1, null, 'sideLength');
    }
    final characters = value.runes.toList(growable: false);
    if (characters.length <= sideLength * 2 + 1) return value;
    return '${String.fromCharCodes(characters.take(sideLength))}'
        '…'
        '${String.fromCharCodes(characters.skip(characters.length - sideLength))}';
  }

  static DateTime? _parseDate(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final normalized = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
        ? '${text}T00:00:00'
        : text;
    return DateTime.tryParse(normalized);
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _firstCharacter(String value) =>
      String.fromCharCode(value.runes.first);

  static String _takeCharacters(String value, int count) =>
      String.fromCharCodes(value.runes.take(count));
}
