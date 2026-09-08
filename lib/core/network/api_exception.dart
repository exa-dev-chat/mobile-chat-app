class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic details;

  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.details,
  });

  @override
  String toString() => 'ApiException: $message (Code: $statusCode, ErrCode: $errorCode)';
}

class NetworkException extends ApiException {
  NetworkException({
    super.message = 'Koneksi internet bermasalah. Periksa jaringan Anda.',
    super.statusCode,
    super.errorCode = 'NETWORK_ERROR',
  });
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({
    super.message = 'Sesi Anda telah berakhir. Silakan login kembali.',
    super.statusCode = 401,
    super.errorCode = 'UNAUTHORIZED',
  });
}

class ForbiddenException extends ApiException {
  ForbiddenException({
    super.message = 'Anda tidak memiliki akses ke fitur ini.',
    super.statusCode = 403,
    super.errorCode = 'FORBIDDEN',
  });
}

class NotFoundException extends ApiException {
  NotFoundException({
    super.message = 'Data yang diminta tidak ditemukan.',
    super.statusCode = 404,
    super.errorCode = 'NOT_FOUND',
  });
}

class ValidationException extends ApiException {
  ValidationException({
    required super.message,
    super.statusCode = 422,
    super.errorCode = 'VALIDATION_ERROR',
    super.details,
  });
}

class ServerException extends ApiException {
  ServerException({
    super.message = 'Terjadi kesalahan pada server. Silakan coba lagi nanti.',
    super.statusCode = 500,
    super.errorCode = 'SERVER_ERROR',
  });
}
