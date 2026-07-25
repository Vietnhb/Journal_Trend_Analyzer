final class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.requestId,
    this.details,
    this.cause,
  });

  final int status;
  final String code;
  final String message;
  final String? requestId;
  final Object? details;
  final Object? cause;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isConflict => status == 409;
  bool get isNetworkError => status == 0;

  String get displayMessage {
    final id = requestId;
    return id == null || id.isEmpty ? message : '$message (Request ID: $id)';
  }

  String get userMessage => displayMessage;

  @override
  String toString() =>
      'ApiException(status: $status, code: $code, message: $message'
      '${requestId == null ? '' : ', requestId: $requestId'})';
}

String apiErrorMessage(Object error) {
  if (error case final ApiException exception) {
    return exception.displayMessage;
  }
  return 'An unexpected error occurred. Please try again.';
}
