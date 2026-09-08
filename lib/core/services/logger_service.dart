import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class LoggerService {
  LoggerService._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 90,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    filter: ProductionFilter(),
  );

  /// Debug log for development details
  static void d(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (kReleaseMode) return;
    final formattedMessage = tag != null ? '[$tag] $message' : message;
    _logger.d(formattedMessage, error: error, stackTrace: stackTrace);
  }

  /// Information log for normal operation events
  static void i(String message, {String? tag}) {
    if (kReleaseMode) return;
    final formattedMessage = tag != null ? '[$tag] $message' : message;
    _logger.i(formattedMessage);
  }

  /// Warning log for non-fatal unexpected events
  static void w(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final formattedMessage = tag != null ? '[$tag] $message' : message;
    _logger.w(formattedMessage, error: error, stackTrace: stackTrace);
  }

  /// Error log for exceptions and critical failures
  static void e(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final formattedMessage = tag != null ? '[$tag] $message' : message;
    _logger.e(formattedMessage, error: error, stackTrace: stackTrace);
  }

  /// Dedicated network log for API requests and responses
  static void network({
    required String method,
    required String url,
    int? statusCode,
    dynamic data,
    dynamic response,
    Duration? duration,
    dynamic error,
  }) {
    if (kReleaseMode) return;
    final status = statusCode != null ? '[$statusCode]' : '[ERROR]';
    final latency = duration != null ? '(${duration.inMilliseconds}ms)' : '';
    final buffer = StringBuffer();
    buffer.writeln('🌐 HTTP $method $url $status $latency');

    if (data != null) {
      buffer.writeln('➡️ Request Payload: $data');
    }
    if (response != null) {
      buffer.writeln('⬅️ Response Data: $response');
    }
    if (error != null) {
      buffer.writeln('❌ Error Detail: $error');
    }

    if (error != null || (statusCode != null && statusCode >= 400)) {
      _logger.w(buffer.toString());
    } else {
      _logger.i(buffer.toString());
    }
  }
}
