import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/snackbar_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../routes/app_routes.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../chat/controllers/chat_controller.dart';

class AuthController extends GetxController {
  final AuthRepository repository;
  final StorageService storageService;

  AuthController({required this.repository, required this.storageService});

  // Text Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Forgot Password Controllers
  final forgotEmailController = TextEditingController();
  final otpCodeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  // Reactive State
  final isLoading = false.obs;
  final isGoogleLoading = false.obs;
  final isAppleLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isOtpSent = false.obs;
  final otpVerified = false.obs;
  final isNewPasswordVisible = false.obs;
  final isConfirmNewPasswordVisible = false.obs;
  final currentUser = Rxn<UserModel>();

  // Registration OTP Controllers & State
  final registerOtpController = TextEditingController();
  final isRegisterOtpSent = false.obs;
  final isRegisterOtpSending = false.obs;

  // Account Linking Loading States
  final isLinkingGoogle = false.obs;
  final isLinkingApple = false.obs;
  final isUnlinkingProvider = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadStoredUser();
  }

  @override
  void onReady() {
    super.onReady();
    if (storageService.isLoggedIn) {
      LoggerService.i(
        'AuthController: user already authenticated, checking status',
        tag: 'AuthController',
      );
      final user = currentUser.value;
      if (user != null && user.needsOnboarding) {
        showAppleOnboardingModal();
      } else {
        Get.offAllNamed(Routes.chats);
      }
    }
  }

  void _loadStoredUser() {
    final profile = storageService.userProfile;
    if (profile != null) {
      currentUser.value = UserModel.fromJson(profile);
    }
  }

  Future<void> reloadCurrentUser() async {
    try {
      final user = await repository.getMe();
      await storageService.saveUserProfile(user.toJson());
      currentUser.value = user;
    } catch (e) {
      LoggerService.w(
        'Failed to reload current user: $e',
        tag: 'AuthController',
      );
    }
  }

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.toggle();
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordVisible.toggle();
  }

  void toggleConfirmNewPasswordVisibility() {
    isConfirmNewPasswordVisible.toggle();
  }

  void resetForgotPasswordFlow() {
    forgotEmailController.clear();
    otpCodeController.clear();
    newPasswordController.clear();
    confirmNewPasswordController.clear();
    isOtpSent.value = false;
    otpVerified.value = false;
  }

  void resetRegisterFlow() {
    registerOtpController.clear();
    isRegisterOtpSent.value = false;
  }

  Future<UserModel?> _resolveAndSaveUser(UserModel? initialUser) async {
    UserModel? user = initialUser;
    if (user == null) {
      try {
        user = await repository.getMe();
      } catch (e) {
        LoggerService.w(
          'Failed to getMe after auth: $e',
          tag: 'AuthController',
        );
      }
    }
    if (user != null) {
      await storageService.saveUserProfile(user.toJson());
      currentUser.value = user;
    }
    return user;
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      SnackbarService.warning('Email dan kata sandi wajib diisi.');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isLoading.value = true;
      LoggerService.i('Attempting login for: $email', tag: 'AuthController');

      final authResponse = await repository.login(
        email: email,
        password: password,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      final user = await _resolveAndSaveUser(authResponse.user);

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Selamat datang kembali${user != null ? ', ${user.name}' : ''}!',
        title: 'Login Berhasil',
      );

      if (user != null && user.needsOnboarding) {
        showAppleOnboardingModal();
      } else {
        Get.offAllNamed(Routes.chats);
      }
    } catch (e) {
      LoggerService.e('Login failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      isGoogleLoading.value = true;
      LoggerService.i('Initiating Google Sign-In flow', tag: 'AuthController');

      final serverClientId = AppConstants.googleServerClientId;
      final iosClientId = AppConstants.googleIosClientId;

      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
        clientId: Platform.isIOS && iosClientId.isNotEmpty ? iosClientId : null,
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        LoggerService.i(
          'Google Sign-In canceled by user',
          tag: 'AuthController',
        );
        return;
      }

      final auth = await account.authentication;
      final authCodeOrToken = auth.idToken ?? account.serverAuthCode;

      if (authCodeOrToken == null || authCodeOrToken.isEmpty) {
        SnackbarService.error('Gagal mendapatkan token otentikasi Google.');
        return;
      }

      LoggerService.i(
        'Sending Google auth code/token to backend',
        tag: 'AuthController',
      );
      final authResponse = await repository.loginWithGoogle(
        code: authCodeOrToken,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      final user = await _resolveAndSaveUser(authResponse.user);

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Selamat datang kembali${user != null ? ', ${user.name}' : ''}!',
        title: 'Login Google Berhasil',
      );

      if (user != null && user.needsOnboarding) {
        showAppleOnboardingModal();
      } else {
        Get.offAllNamed(Routes.chats);
      }
    } catch (e) {
      LoggerService.e('Google Sign-In failed: $e', tag: 'AuthController');
      SnackbarService.error('Otentikasi Google gagal: $e');
    } finally {
      isGoogleLoading.value = false;
    }
  }

  Future<void> loginWithApple() async {
    try {
      isAppleLoading.value = true;
      LoggerService.i('Initiating Apple Sign-In flow', tag: 'AuthController');

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        SnackbarService.error('Gagal mendapatkan token otentikasi Apple.');
        return;
      }

      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [
          credential.givenName,
          credential.familyName,
        ].where((p) => p != null && p.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          fullName = parts.join(' ');
        }
      }

      final appleId = credential.userIdentifier;
      if (appleId != null && appleId.isNotEmpty) {
        await storageService.saveAppleId(appleId);
      }

      LoggerService.i(
        'Sending Apple identity token and apple_id to backend',
        tag: 'AuthController',
      );
      final authResponse = await repository.loginWithApple(
        identityToken: identityToken,
        authorizationCode: credential.authorizationCode,
        name: fullName,
        appleId: appleId,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      final user = await _resolveAndSaveUser(authResponse.user);

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      if (user != null && user.needsOnboarding) {
        SnackbarService.info(
          'Akun Apple berhasil didaftarkan. Harap tautkan akun Google Anda untuk melanjutkan.',
          title: 'Tautkan Akun Google',
        );
        showAppleOnboardingModal();
      } else {
        SnackbarService.success(
          'Selamat datang kembali${user != null ? ', ${user.name}' : ''}!',
          title: 'Login Apple Berhasil',
        );
        Get.offAllNamed(Routes.chats);
      }
    } catch (e) {
      LoggerService.e('Apple Sign-In failed: $e', tag: 'AuthController');
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        LoggerService.i(
          'Apple Sign-In canceled by user',
          tag: 'AuthController',
        );
        return;
      }
      SnackbarService.error('Otentikasi Apple gagal: $e');
    } finally {
      isAppleLoading.value = false;
    }
  }

  Future<void> sendRegisterOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      SnackbarService.warning('Alamat email wajib diisi terlebih dahulu.');
      return;
    }
    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isRegisterOtpSending.value = true;
      final msg = await repository.sendRegistrationOtp(email: email);
      isRegisterOtpSent.value = true;
      SnackbarService.success(msg, title: 'Kode OTP Terkirim');
    } catch (e) {
      LoggerService.e('sendRegisterOtp failed: $e', tag: 'AuthController');
    } finally {
      isRegisterOtpSending.value = false;
    }
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final otpCode = registerOtpController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      SnackbarService.warning('Semua kolom formulir wajib diisi.');
      return;
    }

    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    if (password.length < 8) {
      SnackbarService.warning('Kata sandi minimal 8 karakter.');
      return;
    }

    if (password != confirmPassword) {
      SnackbarService.warning('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    try {
      isLoading.value = true;
      LoggerService.i(
        'Attempting registration for: $email',
        tag: 'AuthController',
      );

      final authResponse = await repository.register(
        email: email,
        name: name,
        password: password,
        code: otpCode.isNotEmpty ? otpCode : null,
      );

      await storageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      await _resolveAndSaveUser(authResponse.user);

      if (Get.isRegistered<FcmService>()) {
        FcmService.to.syncTokenWithBackend();
      }

      SnackbarService.success(
        'Akun Anda berhasil dibuat!',
        title: 'Pendaftaran Sukses',
      );

      resetRegisterFlow();
      Get.offAllNamed(Routes.chats);
    } catch (e) {
      LoggerService.e('Registration failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> linkGoogleAccount() async {
    try {
      isLinkingGoogle.value = true;
      LoggerService.i('Linking Google Account', tag: 'AuthController');

      final serverClientId = AppConstants.googleServerClientId;
      final iosClientId = AppConstants.googleIosClientId;

      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
        clientId: Platform.isIOS && iosClientId.isNotEmpty ? iosClientId : null,
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final account = await googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final auth = await account.authentication;
      final authCodeOrToken = auth.idToken ?? account.serverAuthCode;

      if (authCodeOrToken == null || authCodeOrToken.isEmpty) {
        SnackbarService.error('Gagal mendapatkan token Google.');
        return false;
      }

      await repository.linkGoogle(code: authCodeOrToken);
      await reloadCurrentUser();

      SnackbarService.success(
        'Akun Google berhasil ditautkan!',
        title: 'Tautan Berhasil',
      );

      // If onboarding was required, navigate to chats
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (currentUser.value != null && !currentUser.value!.needsOnboarding) {
        Get.offAllNamed(Routes.chats);
      }
      return true;
    } catch (e) {
      LoggerService.e('linkGoogleAccount failed: $e', tag: 'AuthController');
      SnackbarService.error('Gagal mengaitkan akun Google: $e');
      return false;
    } finally {
      isLinkingGoogle.value = false;
    }
  }

  Future<bool> unlinkGoogleAccount() async {
    try {
      isUnlinkingProvider.value = true;
      await repository.unlinkGoogle();
      await reloadCurrentUser();
      SnackbarService.success('Akun Google berhasil diputuskan.');
      return true;
    } catch (e) {
      LoggerService.e('unlinkGoogleAccount failed: $e', tag: 'AuthController');
      SnackbarService.error(e.toString());
      return false;
    } finally {
      isUnlinkingProvider.value = false;
    }
  }

  Future<bool> linkAppleAccount() async {
    try {
      isLinkingApple.value = true;
      LoggerService.i('Linking Apple Account', tag: 'AuthController');

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        SnackbarService.error('Gagal mendapatkan token Apple.');
        return false;
      }

      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        final parts = [
          credential.givenName,
          credential.familyName,
        ].where((p) => p != null && p.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          fullName = parts.join(' ');
        }
      }

      final appleId = credential.userIdentifier;
      await repository.linkApple(
        identityToken: identityToken,
        appleId: appleId,
        name: fullName,
      );

      await reloadCurrentUser();
      SnackbarService.success('Akun Apple ID berhasil ditautkan!');
      return true;
    } catch (e) {
      LoggerService.e('linkAppleAccount failed: $e', tag: 'AuthController');
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        return false;
      }
      SnackbarService.error('Gagal mengaitkan Apple ID: $e');
      return false;
    } finally {
      isLinkingApple.value = false;
    }
  }

  Future<bool> unlinkAppleAccount() async {
    try {
      isUnlinkingProvider.value = true;
      await repository.unlinkApple();
      await reloadCurrentUser();
      SnackbarService.success('Akun Apple ID berhasil diputuskan.');
      return true;
    } catch (e) {
      LoggerService.e('unlinkAppleAccount failed: $e', tag: 'AuthController');
      SnackbarService.error(e.toString());
      return false;
    } finally {
      isUnlinkingProvider.value = false;
    }
  }

  Future<void> sendEmailVerificationOtp({String? email}) async {
    try {
      isLoading.value = true;
      final msg = await repository.sendVerificationOtp(email: email);
      SnackbarService.success(msg, title: 'Kode Terkirim');
    } catch (e) {
      LoggerService.e(
        'sendEmailVerificationOtp failed: $e',
        tag: 'AuthController',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyEmailOtp(String code, {String? email}) async {
    try {
      isLoading.value = true;
      await repository.verifyEmailOtp(code: code, email: email);
      await reloadCurrentUser();
      SnackbarService.success(
        'Email Anda telah berhasil diverifikasi!',
        title: 'Verifikasi Berhasil',
      );
      return true;
    } catch (e) {
      LoggerService.e('verifyEmailOtp failed: $e', tag: 'AuthController');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void showAppleOnboardingModal() {
    Get.dialog(
      PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF60A5FA),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tautkan Akun Google',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Untuk keamanan akun dan menyelesaikan pendaftaran dengan Apple ID, Anda harus mengaitkan akun Google sebelum dapat menggunakan chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLinkingGoogle.value
                          ? null
                          : linkGoogleAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLinkingGoogle.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'G',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Kaitkan Akun Google Sekarang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: logout,
                  child: const Text(
                    'Keluar Akun',
                    style: TextStyle(color: Color(0xFFF43F5E), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> logout() async {
    try {
      if (Get.isRegistered<FcmService>()) {
        await FcmService.to.removeTokenFromBackend();
      }
      final refreshToken = storageService.refreshToken;
      await repository.logout(refreshToken: refreshToken);
    } catch (e) {
      LoggerService.w('Logout remote call failed: $e', tag: 'AuthController');
    } finally {
      if (Get.isRegistered<ChatController>()) {
        Get.delete<ChatController>(force: true);
      }
      await storageService.clearAuth();
      currentUser.value = null;
      SnackbarService.info('Anda telah keluar dari aplikasi.');
      Get.offAllNamed(Routes.login);
    }
  }

  Future<void> sendForgotPasswordOtp() async {
    final email = forgotEmailController.text.trim();
    if (email.isEmpty) {
      SnackbarService.warning('Alamat email wajib diisi.');
      return;
    }
    if (!GetUtils.isEmail(email)) {
      SnackbarService.warning('Format email tidak valid.');
      return;
    }

    try {
      isLoading.value = true;
      final msg = await repository.forgotPassword(email: email);
      isOtpSent.value = true;
      SnackbarService.success(msg, title: 'Email Terkirim');
    } catch (e) {
      LoggerService.e(
        'sendForgotPasswordOtp failed: $e',
        tag: 'AuthController',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> verifyOtp() async {
    final email = forgotEmailController.text.trim();
    final code = otpCodeController.text.trim();

    if (code.length != 6) {
      SnackbarService.warning('Kode OTP harus 6 digit.');
      return;
    }

    try {
      isLoading.value = true;
      await repository.verifyResetToken(email: email, code: code);
      otpVerified.value = true;
      SnackbarService.success(
        'Kode verifikasi valid. Silakan buat kata sandi baru.',
        title: 'Verifikasi Berhasil',
      );
    } catch (e) {
      LoggerService.e('verifyOtp failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitNewPassword() async {
    final email = forgotEmailController.text.trim();
    final code = otpCodeController.text.trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmNewPasswordController.text;

    if (newPassword.length < 8) {
      SnackbarService.warning('Kata sandi minimal 8 karakter.');
      return;
    }

    if (newPassword != confirmPassword) {
      SnackbarService.warning('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    try {
      isLoading.value = true;
      await repository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      SnackbarService.success(
        'Kata sandi Anda berhasil diperbarui. Silakan masuk kembali.',
        title: 'Berhasil',
      );

      resetForgotPasswordFlow();
      Get.offAllNamed(Routes.login);
    } catch (e) {
      LoggerService.e('submitNewPassword failed: $e', tag: 'AuthController');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    confirmPasswordController.dispose();
    forgotEmailController.dispose();
    otpCodeController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.onClose();
  }
}
