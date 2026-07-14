import 'package:flutter/material.dart';

class ChartEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool compact;

  const ChartEmptyState({
    super.key,
    this.message = 'No chart data available',
    this.icon = Icons.query_stats_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 34 : 44,
              height: compact ? 34 : 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(compact ? 10 : 14),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: compact ? 18 : 22,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
