import 'package:flutter/material.dart';

final class AdminDateRange {
  const AdminDateRange({
    required this.start,
    required this.end,
    required this.label,
    this.isCustom = false,
  });

  factory AdminDateRange.lastMinutes(int minutes, String label) {
    final end = DateTime.now();
    return AdminDateRange(
      start: end.subtract(Duration(minutes: minutes)),
      end: end,
      label: label,
    );
  }

  factory AdminDateRange.lastDays(int days, String label) {
    final end = DateTime.now();
    return AdminDateRange(
      start: end.subtract(Duration(days: days)),
      end: end,
      label: label,
    );
  }

  factory AdminDateRange.custom(DateTime start, DateTime end) => AdminDateRange(
    start: DateTime(start.year, start.month, start.day),
    end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
    label: '${_shortDate(start)} – ${_shortDate(end)}',
    isCustom: true,
  );

  static AdminDateRange get last30Days =>
      AdminDateRange.lastDays(30, '30 ngày qua');

  final DateTime start;
  final DateTime end;
  final String label;
  final bool isCustom;

  String get apiStart => start.toUtc().toIso8601String();
  String get apiEnd => end.toUtc().toIso8601String();

  bool contains(DateTime value) {
    final instant = value.toLocal();
    return !instant.isBefore(start) && !instant.isAfter(end);
  }
}

class AdminDateRangeFilter extends StatelessWidget {
  const AdminDateRangeFilter({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AdminDateRange value;
  final ValueChanged<AdminDateRange> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final result = await showDialog<AdminDateRange>(
        context: context,
        builder: (context) => _DateRangeDialog(initialValue: value),
      );
      if (result != null) onChanged(result);
    },
    icon: Icon(value.isCustom ? Icons.date_range_rounded : Icons.schedule),
    label: Text(value.label),
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
  );
}

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({required this.initialValue});

  final AdminDateRange initialValue;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = DateUtils.dateOnly(widget.initialValue.start);
    _end = DateUtils.dateOnly(widget.initialValue.end);
  }

  void _selectDate(DateTime date) {
    final selected = DateUtils.dateOnly(date);
    setState(() {
      if (_start == null || _end != null) {
        _start = selected;
        _end = null;
      } else if (selected.isBefore(_start!)) {
        _end = _start;
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final presets = <AdminDateRange>[
      AdminDateRange.lastMinutes(60, '60 phút qua'),
      AdminDateRange.lastMinutes(12 * 60, '12 giờ qua'),
      AdminDateRange.lastMinutes(24 * 60, '24 giờ qua'),
      AdminDateRange.lastDays(7, '7 ngày qua'),
      AdminDateRange.lastDays(28, '28 ngày qua'),
      AdminDateRange.lastDays(30, '30 ngày qua'),
      AdminDateRange.lastDays(90, '90 ngày qua'),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 610),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final calendar = _CustomRangePanel(
              start: _start,
              end: _end,
              now: now,
              onDateChanged: _selectDate,
              onApply: _start != null && _end != null
                  ? () => Navigator.of(
                      context,
                    ).pop(AdminDateRange.custom(_start!, _end!))
                  : null,
            );
            final quickRanges = _QuickRanges(
              ranges: presets,
              onSelected: (range) => Navigator.of(context).pop(range),
            );
            if (constraints.maxWidth < 620) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 500, child: calendar),
                    const Divider(height: 1),
                    quickRanges,
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: calendar),
                const VerticalDivider(width: 1),
                SizedBox(width: 190, child: quickRanges),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CustomRangePanel extends StatelessWidget {
  const _CustomRangePanel({
    required this.start,
    required this.end,
    required this.now,
    required this.onDateChanged,
    required this.onApply,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime now;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Tùy chỉnh',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DateBox(value: start, placeholder: 'Ngày bắt đầu'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 16),
            ),
            Expanded(
              child: _DateBox(value: end, placeholder: 'Ngày kết thúc'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          end == null
              ? 'Chọn ngày bắt đầu, sau đó chọn ngày kết thúc.'
              : 'Khoảng đã chọn: ${_shortDate(start!)} – ${_shortDate(end!)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _RangeCalendar(
            initialMonth: end ?? start ?? now,
            start: start,
            end: end,
            firstDate: DateTime(now.year - 5),
            lastDate: now,
            onDateChanged: onDateChanged,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Áp dụng'),
          ),
        ),
      ],
    ),
  );
}

class _RangeCalendar extends StatefulWidget {
  const _RangeCalendar({
    required this.initialMonth,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
  });

  final DateTime initialMonth;
  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<_RangeCalendar> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  bool get _canGoBack {
    final previous = DateTime(_month.year, _month.month - 1);
    return !previous.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
  }

  bool get _canGoForward {
    final next = DateTime(_month.year, _month.month + 1);
    return !next.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  void _moveMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_month.year, _month.month);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = firstOfMonth.weekday - DateTime.monday;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Column(
      children: [
        Row(
          children: [
            Text(
              'THÁNG ${_month.month.toString().padLeft(2, '0')} ${_month.year}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Tháng trước',
              onPressed: _canGoBack ? () => _moveMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Tháng sau',
              onPressed: _canGoForward ? () => _moveMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_month.year, _month.month, day);
              return _RangeDay(
                date: date,
                start: widget.start,
                end: widget.end,
                enabled:
                    !date.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
                    !date.isAfter(DateUtils.dateOnly(widget.lastDate)),
                onTap: () => widget.onDateChanged(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RangeDay extends StatelessWidget {
  const _RangeDay({
    required this.date,
    required this.start,
    required this.end,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final DateTime? start;
  final DateTime? end;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedStart = start != null && DateUtils.isSameDay(date, start);
    final selectedEnd = end != null && DateUtils.isSameDay(date, end);
    final inRange =
        start != null &&
        end != null &&
        !date.isBefore(start!) &&
        !date.isAfter(end!);
    final scheme = Theme.of(context).colorScheme;
    final endpoint = selectedStart || selectedEnd;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (inRange)
            Positioned(
              left: selectedStart ? 18 : 0,
              right: selectedEnd ? 18 : 0,
              top: 5,
              bottom: 5,
              child: ColoredBox(color: scheme.primary.withValues(alpha: .16)),
            ),
          if (endpoint)
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .28),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 34),
            ),
          Text(
            '${date.day}',
            style: TextStyle(
              color: endpoint
                  ? scheme.onPrimary
                  : enabled
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: .3),
              fontSize: 12,
              fontWeight: endpoint ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.value, required this.placeholder});

  final DateTime? value;
  final String placeholder;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Text(
        value == null ? placeholder : _shortDate(value!),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _QuickRanges extends StatelessWidget {
  const _QuickRanges({required this.ranges, required this.onSelected});

  final List<AdminDateRange> ranges;
  final ValueChanged<AdminDateRange> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Khoảng nhanh',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final range in ranges)
          TextButton(
            onPressed: () => onSelected(range),
            style: const ButtonStyle(alignment: Alignment.centerLeft),
            child: Text(range.label),
          ),
      ],
    ),
  );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
