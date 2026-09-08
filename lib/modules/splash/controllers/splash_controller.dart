import 'package:get/get.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  @override
  void onReady() {
    super.onReady();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final isLoggedIn = _storageService.isLoggedIn;
    LoggerService.i('Auth check on splash: isLoggedIn = $isLoggedIn', tag: 'SplashController');

    if (!isLoggedIn) {
      Get.offAllNamed(Routes.login);
      return;
    }

    try {
      final apiClient = Get.find<ApiClient>();
      final response = await apiClient.get(ApiEndpoints.me);
      final responseData = response.data;
      final data = responseData is Map && responseData['data'] != null
          ? responseData['data']
          : responseData;

      if (data is Map) {
        await _storageService.saveUserProfile(Map<String, dynamic>.from(data));
      }
      LoggerService.i('Splash /me verification succeeded, proceeding to chats', tag: 'SplashController');
      Get.offAllNamed(Routes.chats);
    } catch (e) {
      LoggerService.w('Splash /me verification error: $e', tag: 'SplashController');
      // If 401, AuthInterceptor handles refresh or session expiry (clearing storage)
      if (_storageService.isLoggedIn) {
        // Token exists and not revoked (e.g., offline or network error) -> allow into chats
        Get.offAllNamed(Routes.chats);
      } else {
        Get.offAllNamed(Routes.login);
      }
    }
  }
}
