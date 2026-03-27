/// Result model for connection operations
class ConnectionResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final ConnectionResultType type;

  ConnectionResult({
    required this.success,
    this.data,
    this.error,
    this.type = ConnectionResultType.success,
  });

  factory ConnectionResult.success(T data) {
    return ConnectionResult(
      success: true,
      data: data,
      type: ConnectionResultType.success,
    );
  }

  factory ConnectionResult.failure(String error) {
    return ConnectionResult(
      success: false,
      error: error,
      type: ConnectionResultType.error,
    );
  }

  factory ConnectionResult.timeout() {
    return ConnectionResult(
      success: false,
      error: 'Connection timeout',
      type: ConnectionResultType.timeout,
    );
  }

  factory ConnectionResult.unauthorized() {
    return ConnectionResult(
      success: false,
      error: 'Unauthorized',
      type: ConnectionResultType.unauthorized,
    );
  }
}

enum ConnectionResultType {
  success,
  error,
  timeout,
  unauthorized,
}
