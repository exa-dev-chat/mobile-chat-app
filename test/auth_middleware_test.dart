import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/core/services/storage_service.dart';
import 'package:mobile/routes/app_routes.dart';
import 'package:mobile/routes/middlewares/auth_middleware.dart';

class MockStorageService extends StorageService {
  String? _token;
  String? _refreshToken;
  Map<String, dynamic>? _user;

  @override
  String? get accessToken => _token;

  @override
  Future<void> saveAccessToken(String token) async {
    _token = token;
  }

  @override
  String? get refreshToken => _refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Map<String, dynamic>? get userProfile => _user;

  @override
  Future<void> saveUserProfile(Map<String, dynamic> user) async {
    _user = user;
  }

  @override
  Future<void> clearAuth() async {
    _token = null;
    _refreshToken = null;
    _user = null;
  }

  @override
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthMiddleware and GuestMiddleware Tests', () {
    late MockStorageService storageService;
    late GuestMiddleware guestMiddleware;
    late AuthMiddleware authMiddleware;

    setUp(() {
      Get.reset();
      storageService = MockStorageService();
      Get.put<StorageService>(storageService, permanent: true);

      guestMiddleware = GuestMiddleware();
      authMiddleware = AuthMiddleware();
    });

    tearDown(() {
      Get.reset();
    });

    test('GuestMiddleware allows access to login and register when NOT logged in', () {
      expect(storageService.isLoggedIn, isFalse);

      final loginRedirect = guestMiddleware.redirect(Routes.login);
      expect(loginRedirect, isNull, reason: 'Unauthenticated user should be allowed to view login');

      final registerRedirect = guestMiddleware.redirect(Routes.register);
      expect(registerRedirect, isNull, reason: 'Unauthenticated user should be allowed to view register');
    });

    test('GuestMiddleware blocks access and redirects to chats when token exists', () async {
      await storageService.saveAccessToken('valid-mock-jwt-token');
      expect(storageService.isLoggedIn, isTrue);

      final loginRedirect = guestMiddleware.redirect(Routes.login);
      expect(loginRedirect?.name, Routes.chats, reason: 'Authenticated user MUST be redirected away from login');

      final registerRedirect = guestMiddleware.redirect(Routes.register);
      expect(registerRedirect?.name, Routes.chats, reason: 'Authenticated user MUST be redirected away from register');
    });

    test('AuthMiddleware blocks access and redirects to login when NOT logged in', () {
      expect(storageService.isLoggedIn, isFalse);

      final chatsRedirect = authMiddleware.redirect(Routes.chats);
      expect(chatsRedirect?.name, Routes.login, reason: 'Unauthenticated user must be redirected to login');

      final detailRedirect = authMiddleware.redirect(Routes.chatDetail);
      expect(detailRedirect?.name, Routes.login, reason: 'Unauthenticated user must be redirected to login');
    });

    test('AuthMiddleware allows access to protected routes when logged in', () async {
      await storageService.saveAccessToken('valid-mock-jwt-token');
      expect(storageService.isLoggedIn, isTrue);

      final chatsRedirect = authMiddleware.redirect(Routes.chats);
      expect(chatsRedirect, isNull, reason: 'Authenticated user should be allowed into chats');

      final detailRedirect = authMiddleware.redirect(Routes.chatDetail);
      expect(detailRedirect, isNull, reason: 'Authenticated user should be allowed into chat detail');
    });

    test('Logging out clears token and restores access to login and register', () async {
      await storageService.saveAccessToken('valid-mock-jwt-token');
      expect(guestMiddleware.redirect(Routes.login)?.name, Routes.chats);

      // Perform logout
      await storageService.clearAuth();
      expect(storageService.isLoggedIn, isFalse);

      // Now login & register are accessible again
      expect(guestMiddleware.redirect(Routes.login), isNull);
      expect(guestMiddleware.redirect(Routes.register), isNull);
      expect(authMiddleware.redirect(Routes.chats)?.name, Routes.login);
    });
  });
}
