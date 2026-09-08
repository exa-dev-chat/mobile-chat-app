import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';
import '../../services/logger_service.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = AppConstants.maxNetworkRetries,
    this.retryDelay = AppConstants.initialRetryDelay,
  });

  bool _shouldRetry(DioException err) {
    // Explicitly disabled retry
    if (err.requestOptions.extra['no_retry'] == true) {
      return false;
    }

    // Do not retry 4xx errors (client errors, auth, validations)
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return false;
    }

    // Retry on connection timeouts or connection failures
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on 502, 503, 504 server unavailable errors
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return true;
    }

    return false;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['_retry_count'] as int? ?? 0);

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final nextRetry = retryCount + 1;
      final delay = retryDelay * nextRetry;

      LoggerService.w(
        'Retrying request ($nextRetry/$maxRetries) in ${delay.inMilliseconds}ms: '
        '${err.requestOptions.method} ${err.requestOptions.path}',
        tag: 'RetryInterceptor',
      );

      await Future.delayed(delay);

      final newOptions = err.requestOptions;
      newOptions.extra['_retry_count'] = nextRetry;

      try {
        final response = await dio.fetch(newOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      } catch (e) {
        return handler.next(err);
      }
    }

    return super.onError(err, handler);
  }
}
