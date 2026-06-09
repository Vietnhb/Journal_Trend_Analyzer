class AppError implements Exception {
  final String message;
  final String? details;

  AppError(this.message, {this.details});

  @override
  String toString() => details == null ? message : '$message: $details';
}
