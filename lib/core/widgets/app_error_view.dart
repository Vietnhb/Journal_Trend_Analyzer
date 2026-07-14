import 'package:flutter/material.dart';

import '../errors/app_errors.dart';
import 'app_state_view.dart';

class AppErrorView extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const AppErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppStateView(
      icon: Icons.error_outline_rounded,
      title: error.message,
      message: error.details,
      color: colorScheme.error,
      liveRegion: true,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}
