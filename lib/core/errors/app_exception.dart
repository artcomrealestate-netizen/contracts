/// Standard application error codes shared across the contract-system
/// feature set (see docs/Contract_System_TDD_v1.1_EN.md §47). Repositories
/// and use cases throw [AppException] instead of leaking raw
/// Firebase/Firestore exceptions into the presentation layer, so the UI can
/// map a fixed set of codes to user-facing messages.
enum AppErrorCode {
  authRequired,
  permissionDenied,
  validationError,
  resourceNotFound,
  invalidState,
  conflict,
  storageError,
  internalError,
}

class AppException implements Exception {
  final AppErrorCode code;
  final String message;
  final Object? cause;

  const AppException(this.code, this.message, {this.cause});

  @override
  String toString() => 'AppException(${code.name}): $message';
}
