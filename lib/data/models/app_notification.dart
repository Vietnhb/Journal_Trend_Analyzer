class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
  });
}
