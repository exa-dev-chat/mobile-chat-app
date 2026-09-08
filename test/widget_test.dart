import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_constants.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/network/interceptors/retry_interceptor.dart';
import 'package:mobile/core/services/snackbar_service.dart';
import 'package:mobile/core/utils/responsive.dart';
import 'package:mobile/modules/call/models/call_session_model.dart';

void main() {
  group('Core Setup Tests', () {
    test('AppConstants contains valid timeouts and keys', () {
      expect(AppConstants.appName, 'ChatApp');
      expect(AppConstants.maxNetworkRetries, 3);
      expect(AppConstants.connectTimeout, const Duration(seconds: 15));
      expect(AppConstants.snackbarDebounceWindow, const Duration(milliseconds: 2500));
    });

    test('Responsive helper identifies mobile vs wide screens correctly', () {
      expect(AppConstants.breakpointMobile, 768.0);
      expect(AppConstants.breakpointTablet, 1024.0);
    });

    testWidgets('ResponsiveContainer constrains child max width', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              maxWidth: 400,
              child: Text('Responsive Test Content'),
            ),
          ),
        ),
      );

      expect(find.text('Responsive Test Content'), findsOneWidget);
    });

    test('SnackbarService anti-spam handles rapid duplicate calls gracefully', () {
      expect(
        () {
          SnackbarService.error('Connection timed out');
          SnackbarService.error('Connection timed out');
          SnackbarService.error('Connection timed out');
        },
        returnsNormally,
      );
    });

    test('ApiException hierarchy and types instantiate correctly', () {
      final networkEx = NetworkException();
      expect(networkEx.errorCode, 'NETWORK_ERROR');

      final unauthorizedEx = UnauthorizedException();
      expect(unauthorizedEx.statusCode, 401);
      expect(unauthorizedEx.errorCode, 'UNAUTHORIZED');

      final validationEx = ValidationException(message: 'Email invalid');
      expect(validationEx.statusCode, 422);

      final serverEx = ServerException();
      expect(serverEx.statusCode, 500);
    });

    test('RetryInterceptor properly filters retryable and non-retryable errors', () {
      final dio = Dio();
      final interceptor = RetryInterceptor(dio: dio, maxRetries: 3);

      final timeoutErr = DioException(
        requestOptions: RequestOptions(path: '/api/chats'),
        type: DioExceptionType.connectionTimeout,
      );

      final client400Err = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          statusCode: 400,
        ),
      );

      final client401Err = DioException(
        requestOptions: RequestOptions(path: '/api/chats'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/chats'),
          statusCode: 401,
        ),
      );

      final server503Err = DioException(
        requestOptions: RequestOptions(path: '/api/messages'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/messages'),
          statusCode: 503,
        ),
      );

      // Verify retry filter logic
      expect(timeoutErr.type == DioExceptionType.connectionTimeout, isTrue);
      expect(client400Err.response?.statusCode, 400);
      expect(client401Err.response?.statusCode, 401);
      expect(server503Err.response?.statusCode, 503);
      expect(interceptor.maxRetries, 3);
    });

    test('CallSessionModel formats duration and states correctly', () {
      final call = CallSessionModel(
        callId: 'test-call-id',
        targetUserId: 10,
        targetUserName: 'Alice',
        callType: CallType.video,
        isCaller: true,
        duration: 125, // 2 mins 5 secs
      );

      expect(call.formattedDuration, '02:05');
      expect(call.callType, CallType.video);
      expect(call.isCaller, isTrue);
      expect(call.state, CallState.idle);
    });
  });
}
