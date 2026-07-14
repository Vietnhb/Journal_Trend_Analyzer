import 'package:flutter/material.dart';

/// Shared presentation for empty, error, and informational states.
///
/// Keeping the layout in one place gives all feature screens the same spacing,
/// responsive width, semantics, and visual hierarchy.
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? message;
  final Color? color;
  final Widget? action;
  final bool liveRegion;

  const AppStateView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.color,
    this.action,
    this.liveRegion = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = color ?? theme.colorScheme.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Semantics(
            container: true,
            liveRegion: liveRegion,
            label: [title, message].whereType<String>().join('. '),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(icon, size: 31, color: stateColor),
                ),
                if (title != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (message != null) ...[
                  SizedBox(height: title == null ? 18 : 7),
                  Text(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 22), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
