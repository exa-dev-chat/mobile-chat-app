import 'package:dio/dio.dart';
import '../../services/logger_service.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_request_start_time'] = DateTime.now().millisecondsSinceEpoch;
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra['_request_start_time'] as int?;
    final duration = startTime != null
        ? Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - startTime)
        : null;

    LoggerService.network(
      method: response.requestOptions.method,
      url: response.requestOptions.uri.toString(),
      statusCode: response.statusCode,
      data: response.requestOptions.data,
      response: response.data,
      duration: duration,
    );

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra['_request_start_time'] as int?;
    final duration = startTime != null
        ? Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - startTime)
        : null;

    LoggerService.network(
      method: err.requestOptions.method,
      url: err.requestOptions.uri.toString(),
      statusCode: err.response?.statusCode,
      data: err.requestOptions.data,
      response: err.response?.data,
      duration: duration,
      error: err.message,
    );

    super.onError(err, handler);
  }
}
