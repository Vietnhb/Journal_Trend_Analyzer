import 'package:flutter/material.dart';

import 'app_state_view.dart';

class AppEmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.search_rounded,
    this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final action = onAction != null && actionLabel != null
        ? actionIcon == null
              ? OutlinedButton(onPressed: onAction, child: Text(actionLabel!))
              : OutlinedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel!),
                )
        : null;

    return AppStateView(
      icon: icon,
      title: title,
      message: message,
      action: action,
    );
  }
}
