import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

export 'date_range_filter.dart';

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actions,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
    if (actions == null || actions!.isEmpty) return text;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: actions!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 20),
            Wrap(spacing: 10, runSpacing: 10, children: actions!),
          ],
        );
      },
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 16), trailing!],
    ],
  );
}

enum MetricTone { blue, violet, green, amber, red }

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.tone = MetricTone.blue,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final MetricTone tone;

  Color _color() => switch (tone) {
    MetricTone.blue => AppTheme.brand,
    MetricTone.violet => AppTheme.accent,
    MetricTone.green => AppTheme.success,
    MetricTone.amber => AppTheme.warning,
    MetricTone.red => AppTheme.danger,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum StatusTone { neutral, info, success, warning, danger, purple }

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    this.tone = StatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      StatusTone.info => (AppTheme.brand, const Color(0xFFDBEAFE)),
      StatusTone.success => (AppTheme.success, const Color(0xFFD1FAE5)),
      StatusTone.warning => (AppTheme.warning, const Color(0xFFFEF3C7)),
      StatusTone.danger => (AppTheme.danger, const Color(0xFFFEE2E2)),
      StatusTone.purple => (AppTheme.accent, const Color(0xFFEDE9FE)),
      StatusTone.neutral => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? colors.$1.withValues(alpha: .16)
            : colors.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colors.$1, size: 13),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: colors.$1,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count =
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
              .floor()
              .clamp(1, 4);
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({this.label = 'Đang tải dữ liệu…', super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppTheme.danger,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Không thể tải dữ liệu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.fromLTRB(
        constraints.maxWidth < 600 ? 16 : 24,
        constraints.maxWidth < 600 ? 22 : 28,
        constraints.maxWidth < 600 ? 16 : 24,
        48,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(children),
            ),
          ),
        ),
      ],
    ),
  );

  static List<Widget> _withSpacing(List<Widget> widgets) => [
    for (var i = 0; i < widgets.length; i++) ...[
      widgets[i],
      if (i != widgets.length - 1) const SizedBox(height: 22),
    ],
  ];
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppTheme.danger : const Color(0xFF172033),
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}

Future<bool> showTypedConfirmation({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmationText,
  String actionLabel = 'Xác nhận',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _TypedConfirmationDialog(
      title: title,
      description: description,
      confirmationText: confirmationText,
      actionLabel: actionLabel,
      danger: danger,
    ),
  );
  return result ?? false;
}

class _TypedConfirmationDialog extends StatefulWidget {
  const _TypedConfirmationDialog({
    required this.title,
    required this.description,
    required this.confirmationText,
    required this.actionLabel,
    required this.danger,
  });

  final String title;
  final String description;
  final String confirmationText;
  final String actionLabel;
  final bool danger;

  @override
  State<_TypedConfirmationDialog> createState() =>
      _TypedConfirmationDialogState();
}

class _TypedConfirmationDialogState extends State<_TypedConfirmationDialog> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          const SizedBox(height: 18),
          Text.rich(
            TextSpan(
              text: 'Nhập ',
              children: [
                TextSpan(
                  text: widget.confirmationText,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(text: ' để tiếp tục.'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (value) =>
                setState(() => _valid = value == widget.confirmationText),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _valid ? _submit : null,
        style: widget.danger
            ? FilledButton.styleFrom(backgroundColor: AppTheme.danger)
            : null,
        child: Text(widget.actionLabel),
      ),
    ],
  );
}
