import 'package:dio/dio.dart';
import '../api_exception.dart';
import '../../services/snackbar_service.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = _mapDioException(err);

    // Automatically notify user via anti-spam snackbar unless explicitly disabled
    final shouldShowSnackbar = err.requestOptions.extra['show_snackbar'] != false;
    if (shouldShowSnackbar) {
      SnackbarService.error(
        apiException.message,
        title: _getErrorTitle(apiException.statusCode),
      );
    }

    final customErr = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: apiException,
      message: apiException.message,
    );

    return handler.next(customErr);
  }

  ApiException _mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Koneksi ke server terputus atau waktu habis. Periksa jaringan Anda.',
        );

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;
        String message = 'Terjadi kesalahan tidak terduga.';

        // Extract message from FastAPI response schema
        if (data is Map) {
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            message = data['message'].toString();
          } else if (data['detail'] != null) {
            if (data['detail'] is String) {
              message = data['detail'];
            } else if (data['detail'] is List && (data['detail'] as List).isNotEmpty) {
              // FastAPI Pydantic validation error
              final firstError = data['detail'][0];
              if (firstError is Map && firstError['msg'] != null) {
                message = firstError['msg'].toString();
              }
            }
          }
        }

        switch (statusCode) {
          case 400:
            return ApiException(message: message, statusCode: 400, errorCode: 'BAD_REQUEST');
          case 401:
            return UnauthorizedException(message: message);
          case 403:
            return ForbiddenException(message: message);
          case 404:
            return NotFoundException(message: message);
          case 422:
            return ValidationException(message: message, details: data);
          case 500:
          case 502:
          case 503:
          case 504:
            return ServerException(message: message);
          default:
            return ApiException(message: message, statusCode: statusCode);
        }

      case DioExceptionType.cancel:
        return ApiException(message: 'Permintaan dibatalkan.', errorCode: 'CANCELLED');

      default:
        return ApiException(
          message: err.message ?? 'Terjadi kesalahan pada aplikasi.',
          errorCode: 'UNKNOWN_ERROR',
        );
    }
  }

  String _getErrorTitle(int? statusCode) {
    if (statusCode == null) return 'Koneksi Bermasalah';
    if (statusCode == 401) return 'Sesi Berakhir';
    if (statusCode == 403) return 'Akses Ditolak';
    if (statusCode == 404) return 'Tidak Ditemukan';
    if (statusCode == 422) return 'Validasi Gagal';
    if (statusCode >= 500) return 'Server Error';
    return 'Gagal Memproses';
  }
}
