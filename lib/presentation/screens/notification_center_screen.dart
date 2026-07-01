import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/firebase_provider.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FirebaseProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        actions: [
          TextButton(
            onPressed: notifications.isEmpty
                ? null
                : provider.clearNotifications,
            child: const Text('Clear'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No FCM notifications received yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_rounded),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.body}\n${item.receivedAt.toLocal()}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
