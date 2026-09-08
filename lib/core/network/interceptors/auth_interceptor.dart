import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as get_x;
import '../../constants/api_endpoints.dart';
import '../../constants/app_constants.dart';
import '../../services/logger_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/storage_service.dart';
import '../../../routes/app_routes.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final StorageService storageService;

  // Concurrency lock for token refreshing
  static Completer<bool>? _refreshCompleter;

  AuthInterceptor({
    required this.dio,
    required this.storageService,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Avoid adding token to public auth endpoints
    final path = options.path;
    final isPublicEndpoint = path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.register) ||
        path.contains(ApiEndpoints.refresh);

    if (!isPublicEndpoint) {
      final token = storageService.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final statusCode = response?.statusCode;
    final path = err.requestOptions.path;

    // Only handle 401 Unauthorized
    if (statusCode != 401) {
      return handler.next(err);
    }

    // Do not attempt refresh on auth endpoints to prevent infinite loops
    if (path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.register) ||
        path.contains(ApiEndpoints.refresh)) {
      return handler.next(err);
    }

    final refreshToken = storageService.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleSessionExpired();
      return handler.next(err);
    }

    // Handle token refresh with concurrency lock
    bool refreshSuccess = false;

    if (_refreshCompleter != null) {
      // Another request is already refreshing the token, await it
      LoggerService.i('Awaiting existing token refresh...', tag: 'AuthInterceptor');
      refreshSuccess = await _refreshCompleter!.future;
    } else {
      // This request initiates the token refresh
      _refreshCompleter = Completer<bool>();
      LoggerService.i('Initiating token refresh...', tag: 'AuthInterceptor');

      try {
        // Create isolated Dio instance to avoid interceptor loop
        final tokenDio = Dio(
          BaseOptions(
            baseUrl: dio.options.baseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        );

        final refreshResponse = await tokenDio.post(
          ApiEndpoints.refresh,
          data: {'refresh_token': refreshToken},
        );

        if (refreshResponse.statusCode == 200 || refreshResponse.statusCode == 201) {
          final data = refreshResponse.data['data'] ?? refreshResponse.data;
          final newAccessToken = data['access_token'] as String?;
          final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;

          if (newAccessToken != null) {
            await storageService.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );
            refreshSuccess = true;
            LoggerService.i('Token refreshed successfully', tag: 'AuthInterceptor');
          }
        }
      } catch (e) {
        LoggerService.e('Token refresh failed: $e', tag: 'AuthInterceptor');
        refreshSuccess = false;
      } finally {
        _refreshCompleter?.complete(refreshSuccess);
        _refreshCompleter = null;
      }
    }

    if (refreshSuccess) {
      // Retry original request with the fresh token
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer ${storageService.accessToken}';

      try {
        final retryResponse = await dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      } catch (e) {
        return handler.next(err);
      }
    } else {
      await _handleSessionExpired();
      return handler.next(err);
    }
  }

  Future<void> _handleSessionExpired() async {
    LoggerService.w('Session expired. Logging out...', tag: 'AuthInterceptor');
    await storageService.clearAuth();
    SnackbarService.warning(
      'Sesi Anda telah berakhir. Silakan masuk kembali.',
      title: 'Sesi Berakhir',
    );
    get_x.Get.offAllNamed(Routes.login);
  }
}
