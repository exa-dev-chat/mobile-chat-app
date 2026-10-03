import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../constants/app_constants.dart';
import 'logger_service.dart';

class StorageService extends GetxService {
  late final GetStorage _box;

  Future<StorageService> init() async {
    await GetStorage.init();
    _box = GetStorage();
    LoggerService.i('StorageService initialized successfully', tag: 'StorageService');
    return this;
  }

  // Access Token
  String? get accessToken => _box.read<String>(AppConstants.storageKeyAccessToken);
  Future<void> saveAccessToken(String token) async {
    await _box.write(AppConstants.storageKeyAccessToken, token);
  }

  // Refresh Token
  String? get refreshToken => _box.read<String>(AppConstants.storageKeyRefreshToken);
  Future<void> saveRefreshToken(String token) async {
    await _box.write(AppConstants.storageKeyRefreshToken, token);
  }

  // Save both tokens helper
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  // User Profile
  Map<String, dynamic>? get userProfile {
    final data = _box.read(AppConstants.storageKeyUser);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  int get currentUserId {
    final profile = userProfile;
    if (profile != null) {
      final rawId = profile['id'] ?? profile['user_id'];
      if (rawId is int) return rawId;
      if (rawId != null) return int.tryParse('$rawId') ?? 0;
    }
    return 0;
  }

  Future<void> saveUserProfile(Map<String, dynamic> user) async {
    await _box.write(AppConstants.storageKeyUser, user);
  }

  // Clear Session
  Future<void> clearAuth() async {
    await _box.remove(AppConstants.storageKeyAccessToken);
    await _box.remove(AppConstants.storageKeyRefreshToken);
    await _box.remove(AppConstants.storageKeyUser);
    LoggerService.i('User session cleared from storage', tag: 'StorageService');
  }

  // Check login state
  bool get isLoggedIn {
    final token = accessToken;
    return token != null && token.isNotEmpty;
  }

  // Apple ID
  String? get appleId => _box.read<String>('apple_id');
  Future<void> saveAppleId(String id) async => await _box.write('apple_id', id);
  Future<void> clearAppleId() async => await _box.remove('apple_id');

  // FCM Token
  String? get fcmToken => _box.read<String>('fcm_token');
  Future<void> saveFcmToken(String token) async {
    await _box.write('fcm_token', token);
  }
  Future<void> clearFcmToken() async {
    await _box.remove('fcm_token');
  }
}

